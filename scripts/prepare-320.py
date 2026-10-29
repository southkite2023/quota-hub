"""Prepare immutable 3.2.0 packages from a successful, exact-source native run."""
import argparse, hashlib, io, json, os, plistlib, re, struct, subprocess, zipfile
from pathlib import Path, PurePosixPath
REPO='southkite2023/quota-hub'
VERSION='3.2.0'
BUILD='22'
def api(path):
    return json.loads(subprocess.check_output(['gh','api',f'repos/{REPO}/{path}']))
def verified_zip(artifact, sha, run):
    assert not artifact['expired']
    assert artifact['workflow_run']['head_sha']==sha and artifact['workflow_run']['id']==run
    digest=artifact['digest']; assert re.fullmatch(r'sha256:[a-f0-9]{64}',digest)
    blob=subprocess.check_output(['gh','api',f"repos/{REPO}/actions/artifacts/{artifact['id']}/zip"])
    assert hashlib.sha256(blob).hexdigest()==digest[7:]
    with zipfile.ZipFile(io.BytesIO(blob)) as z:
        assert z.testzip() is None
        for name in z.namelist():
            p=PurePosixPath(name.replace('\\','/'))
            assert not p.is_absolute() and '..' not in p.parts
    return blob

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--only',choices=['windows','macos']); args=parser.parse_args()
    sha=os.environ['SOURCE_SHA']; run_id=int(os.environ['NATIVE_RUN_ID'])
    assert re.fullmatch(r'[0-9a-f]{40}',sha)
    assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==sha
    run=api(f'actions/runs/{run_id}')
    assert run['head_sha']==sha and run['head_branch']=='main' and run['event']=='push' and run['conclusion']=='success'
    assert run['path']=='.github/workflows/client-native.yml'
    # Each required workflow must pass against precisely the production source.
    for workflow in ['client-web.yml','server.yml']:
        runs=api(f'actions/workflows/{workflow}/runs?head_sha={sha}&event=push&per_page=100')['workflow_runs']
        assert any(r['head_sha']==sha and r['conclusion']=='success' for r in runs), workflow+' has not passed'
    artifacts=api(f'actions/runs/{run_id}/artifacts?per_page=100')['artifacts']
    indexed={a['name']:a for a in artifacts}
    required={'quota-hub-android-signed','astracct-windows-candidate','astracct-macos-candidate'}
    assert required.issubset(indexed)
    root=Path('release'); root.mkdir(exist_ok=True)
    if args.only in (None,'windows'):
        blob=verified_zip(indexed['astracct-windows-candidate'],sha,run_id)
        with zipfile.ZipFile(io.BytesIO(blob)) as z:
            assert all(n in z.namelist() for n in ['astracct.exe','flutter_windows.dll','data/app.so'])
        (root/f'astracct-{VERSION}-windows-x64.zip').write_bytes(blob)
    if args.only in (None,'macos'):
        blob=verified_zip(indexed['astracct-macos-candidate'],sha,run_id)
        with zipfile.ZipFile(io.BytesIO(blob)) as outer:
            app_zip=outer.read('Astracct-macos.zip')
            dmg=outer.read('Astracct-macos.dmg')
        assert dmg[-512:-508]==b'koly', 'Invalid DMG trailer'
        with zipfile.ZipFile(io.BytesIO(app_zip)) as app:
            assert app.testzip() is None
            info=plistlib.loads(app.read('Astracct.app/Contents/Info.plist'))
            assert info['CFBundleIdentifier']=='com.yuashie.astracct'
            assert info['CFBundleShortVersionString']==VERSION and str(info['CFBundleVersion'])==BUILD
            assert info['FLTEnableImpeller'] is False
            binary=app.read('Astracct.app/Contents/MacOS/Astracct')
            assert binary[:4]==bytes.fromhex('cafebabe')
            count=struct.unpack_from('>I',binary,4)[0]
            assert {struct.unpack_from('>I',binary,8+20*i)[0] for i in range(count)}=={0x1000007,0x100000c}
        (root/f'astracct-{VERSION}-macos-universal.zip').write_bytes(app_zip)
        (root/f'astracct-{VERSION}-macos-universal.dmg').write_bytes(dmg)
    if args.only:return
    blob=verified_zip(indexed['quota-hub-android-signed'],sha,run_id)
    with zipfile.ZipFile(io.BytesIO(blob)) as z:z.extractall('android-release')
    tools=sorted(Path(os.environ['ANDROID_HOME'],'build-tools').glob('*'))[-1]
    subprocess.run(['python3','scripts/inspect-android-apks.py','--directory','android-release','--aapt',str(tools/'aapt'),'--zipalign',str(tools/'zipalign'),'--version',VERSION,'--build-number',BUILD],check=True)
    certificate=Path('docs/ANDROID_SIGNING_SHA256.txt').read_text().strip()
    report=json.loads(Path('android-release/apk-report.json').read_text()); assert len(report)==4
    for item in report:
        source=Path('android-release',item['file'])
        output=subprocess.check_output([str(tools/'apksigner'),'verify','--print-certs',str(source)],text=True)
        assert {m.lower() for m in re.findall(r'Signer.*certificate SHA-256 digest: ([0-9a-fA-F]+)',output)}=={certificate}
        (root/source.name).write_bytes(source.read_bytes())
    (root/'apk-report.json').write_text(json.dumps(report,indent=2)+'\n')
    manifest=[{'file':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(root.iterdir()) if p.suffix in ('.apk','.zip','.dmg')]
    assert len(manifest)==7
    (root/'packages.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (root/'SHA256SUMS.txt').write_text(''.join(f"{p['sha256']}  {p['file']}\n" for p in manifest))
    (root/'provenance.json').write_text(json.dumps({'source':sha,'nativeRun':run_id,'artifacts':{n:{'id':indexed[n]['id'],'digest':indexed[n]['digest']} for n in sorted(required)}},indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__':main()
