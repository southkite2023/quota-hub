import hashlib, json, os, pathlib, subprocess, zipfile, plistlib, struct, re
root=pathlib.Path('release');root.mkdir()
def api(path):
    return json.loads(subprocess.check_output(['gh','api',path]))
repo='repos/southkite2023/quota-hub'
run=api(repo+'/actions/runs/37741806130')
assert run['conclusion']=='success' and run['head_sha']=='36120a8745a2f52235c9b5b0c7fe5c34a9785154'
assert api(repo+'/actions/runs/37741806102')['conclusion']=='success'
artifacts={a['id']:a for a in api(repo+'/actions/runs/37741806130/artifacts')['artifacts']}
expected={"11534281870":"d3f2aeaca9f73044ad9ee644320a79733ea6eb6186f442214797a4bc46240db4","11534142932":"331dbd289937353955efc6cfe0b8b2abd603374be273458546dd57f45c9dbbec","11534098591":"a792812fc5462c30ef7a727b7e39737e015282224014798e638fdb010aa607c0"}
for aid,digest in expected.items():
    aid = int(aid)
    assert not artifacts[aid]['expired'] and artifacts[aid]['digest']=='sha256:'+digest
    blob=subprocess.check_output(['gh','api',repo+f'/actions/artifacts/{aid}/zip'])
    assert hashlib.sha256(blob).hexdigest()==digest
    path=pathlib.Path(f'{aid}.zip');path.write_bytes(blob)
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None
        if artifacts[aid]['name']=='quota-hub-android-signed':
            z.extractall('android-release')
        elif artifacts[aid]['name']=='astracct-windows-candidate':
            assert all(n in z.namelist() for n in ['astracct.exe','flutter_windows.dll','data/app.so'])
            (root/'astracct-0.10.0-windows-x64.zip').write_bytes(blob)
        else:
            inner=z.read('Astracct-macos.zip')
            (root/'astracct-0.10.0-macos-universal.zip').write_bytes(inner)
            with zipfile.ZipFile(root/'astracct-0.10.0-macos-universal.zip') as app:
                info=plistlib.loads(app.read('Astracct.app/Contents/Info.plist'))
                assert info['CFBundleIdentifier']=='com.yuashie.astracct' and info['CFBundleShortVersionString']=='0.10.0' and info['CFBundleVersion']=='13'
                # Confirm packaged executable architecture rather than guessing from runner.
                binary=app.read('Astracct.app/Contents/MacOS/Astracct')
                assert binary[:4]==bytes.fromhex('cafebabe')
                count=struct.unpack_from('>I',binary,4)[0]
                assert {struct.unpack_from('>I',binary,8+20*i)[0] for i in range(count)}=={0x1000007,0x100000c}, 'Expected Intel + Apple Silicon universal executable'
build_tools=sorted(pathlib.Path(os.environ['ANDROID_HOME'],'build-tools').glob('*'))[-1]
subprocess.run(['python3','scripts/inspect-android-apks.py','--directory','android-release','--aapt',str(build_tools/'aapt'),'--zipalign',str(build_tools/'zipalign'),'--version','0.10.0','--build-number','13'],check=True)
cert=pathlib.Path('docs/ANDROID_SIGNING_SHA256.txt').read_text().strip()
report=json.loads(pathlib.Path('android-release/apk-report.json').read_text())
for item in report:
    src=pathlib.Path('android-release',item['file'])
    output=subprocess.check_output([str(build_tools/'apksigner'),'verify','--print-certs',str(src)],text=True)
    fingerprints={m.lower() for m in re.findall(r'Signer.*certificate SHA-256 digest: ([0-9a-fA-F]+)',output)}
    assert fingerprints=={cert}, f'Certificate mismatch: {fingerprints}'
    name=item['file'].replace('quota-hub-','astracct-')
    (root/name).write_bytes(src.read_bytes());item['file']=name
(root/'apk-report.json').write_text(json.dumps(report,indent=2)+'\n')
manifest=[{'file':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(root.glob('*')) if p.suffix in ['.apk','.zip']]
(root/'packages.json').write_text(json.dumps(manifest,indent=2)+'\n')
(root/'SHA256SUMS.txt').write_text(''.join(f"{p['sha256']}  {p['file']}\n" for p in manifest))
print(json.dumps(manifest,indent=2))

