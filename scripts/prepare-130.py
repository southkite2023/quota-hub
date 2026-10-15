"""One-time publisher: only artifacts from the exact verified source may be released."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import struct
import subprocess
import zipfile

REPO='southkite2023/quota-hub'
SHA='b4b4c4c27d27fa09d4f1f62dd4909ea5062dca53'
RUN=38687215325
ARTIFACTS = {
    'astracct-windows-candidate': (11950193278, '993fc6b440b5f178519aa82a3afde97db6efe22974db12a2b35f8a11c06760ed'),
    'quota-hub-android-signed': (11950153517, 'fa34fd9eaab6f49098eb10fe090e7d036bb0e149a368e0f4a90ed3421ae056c1'),
    'astracct-macos-candidate': (11949943972, '0fb112e0735b6ece6a94a7176861f01df0e624c23aa71ce8041cd655085fb435'),
}

def api(path): return json.loads(subprocess.check_output(['gh','api',f'repos/{REPO}/{path}']))
def verified_zip(name):
    metadata=api(f'actions/artifacts/{ARTIFACTS[name][0]}')
    digest=ARTIFACTS[name][1]
    assert metadata['digest']=='sha256:'+digest and not metadata['expired']
    assert metadata['workflow_run']['head_sha']==SHA and metadata['workflow_run']['id']==RUN
    blob=subprocess.check_output(['gh','api',f'repos/{REPO}/actions/artifacts/{ARTIFACTS[name][0]}/zip'])
    assert hashlib.sha256(blob).hexdigest()==digest
    with zipfile.ZipFile(io.BytesIO(blob)) as z:
        assert z.testzip() is None
        for name in z.namelist():
            p=PurePosixPath(name.replace('\\','/'))
            assert not p.is_absolute() and '..' not in p.parts
    return blob

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--only',choices=['windows','macos']); args=parser.parse_args()
    for run_id in (RUN,38687215315,38687215316):
        run=api(f'actions/runs/{run_id}')
        assert run['head_sha']==SHA and run['conclusion']=='success'
    root=Path('release');root.mkdir(exist_ok=True)
    if args.only in (None,'windows'):
        blob=verified_zip('astracct-windows-candidate')
        with zipfile.ZipFile(io.BytesIO(blob)) as z:
            assert all(n in z.namelist() for n in ['astracct.exe','flutter_windows.dll','data/app.so'])
        (root/'astracct-1.3.0-windows-x64.zip').write_bytes(blob)
    if args.only in (None,'macos'):
        with zipfile.ZipFile(io.BytesIO(verified_zip('astracct-macos-candidate'))) as outer:
            blob=outer.read('Astracct-macos.zip')
        with zipfile.ZipFile(io.BytesIO(blob)) as app:
            assert app.testzip() is None
            info=plistlib.loads(app.read('Astracct.app/Contents/Info.plist'))
            assert info['CFBundleIdentifier']=='com.yuashie.astracct' and info['CFBundleShortVersionString']=='1.3.0' and info['CFBundleVersion']=='17'
            assert info['FLTEnableImpeller'] is False
            binary=app.read('Astracct.app/Contents/MacOS/Astracct')
            assert binary[:4]==bytes.fromhex('cafebabe')
            count=struct.unpack_from('>I',binary,4)[0]
            assert {struct.unpack_from('>I',binary,8+20*i)[0] for i in range(count)}=={0x1000007,0x100000c}
        (root/'astracct-1.3.0-macos-universal.zip').write_bytes(blob)
    if args.only: return
    with zipfile.ZipFile(io.BytesIO(verified_zip('quota-hub-android-signed'))) as z: z.extractall('android-release')
    tools=sorted(Path(os.environ['ANDROID_HOME'],'build-tools').glob('*'))[-1]
    subprocess.run(['python3','scripts/inspect-android-apks.py','--directory','android-release','--aapt',str(tools/'aapt'),'--zipalign',str(tools/'zipalign'),'--version','1.3.0','--build-number','17'],check=True)
    certificate=Path('docs/ANDROID_SIGNING_SHA256.txt').read_text().strip()
    report=json.loads(Path('android-release/apk-report.json').read_text())
    assert len(report)==4
    for item in report:
        source=Path('android-release',item['file'])
        output=subprocess.check_output([str(tools/'apksigner'),'verify','--print-certs',str(source)],text=True)
        assert {m.lower() for m in re.findall(r'Signer.*certificate SHA-256 digest: ([0-9a-fA-F]+)',output)}=={certificate}
        permissions=subprocess.check_output([str(tools/'aapt'),'dump','permissions',str(source)],text=True)
        assert 'android.permission.REQUEST_INSTALL_PACKAGES' in permissions
        (root/item['file']).write_bytes(source.read_bytes())
    (root/'apk-report.json').write_text(json.dumps(report,indent=2)+'\n')
    manifest=[{'file':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(root.iterdir()) if p.suffix in ('.apk','.zip')]
    assert len(manifest)==6
    (root/'packages.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (root/'SHA256SUMS.txt').write_text(''.join(f"{p['sha256']}  {p['file']}\n" for p in manifest))
    print(json.dumps(manifest,indent=2))

if __name__=='__main__': main()
