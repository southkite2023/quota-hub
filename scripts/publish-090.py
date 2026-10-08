import hashlib, json, os, pathlib, subprocess, zipfile, plistlib, struct, re
root=pathlib.Path('release');root.mkdir()
def api(path):
    return json.loads(subprocess.check_output(['gh','api',path]))
repo='repos/southkite2023/quota-hub'
run=api(repo+'/actions/runs/37734459516')
assert run['conclusion']=='success' and run['head_sha']=='1843ef382cb3a616443c54421618fbdb03707f1a'
assert api(repo+'/actions/runs/37734459611')['conclusion']=='success'
artifacts={a['id']:a for a in api(repo+'/actions/runs/37734459516/artifacts')['artifacts']}
expected={11530624437:'d65e046cc144b16339ce737ccc05a789ca3750381949db04b9975d911f6bef0e',11531018234:'e313bdbb2ea17a4ca42827f12cb2d4c5537cb0a4c239fdc20aef9c88073d5b0a',11530854902:'dcf1ed171ee668d224c9eb310d0f975307a041147ed59aa205f8a7a285600a90'}
for aid,digest in expected.items():
    assert not artifacts[aid]['expired'] and artifacts[aid]['digest']=='sha256:'+digest
    blob=subprocess.check_output(['gh','api',repo+f'/actions/artifacts/{aid}/zip'])
    assert hashlib.sha256(blob).hexdigest()==digest
    path=pathlib.Path(f'{aid}.zip');path.write_bytes(blob)
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None
        if aid==11530624437:
            z.extractall('android-release')
        elif aid==11531018234:
            assert all(n in z.namelist() for n in ['astracct.exe','flutter_windows.dll','data/app.so'])
            (root/'astracct-0.9.0-windows-x64.zip').write_bytes(blob)
        else:
            inner=z.read('Astracct-macos.zip')
            assert hashlib.sha256(inner).hexdigest()=='9bd7f2763eaa0a2c4954203d58261136a943486e1aae9adc0537d0e03fe5a231'
            (root/'astracct-0.9.0-macos-universal.zip').write_bytes(inner)
            with zipfile.ZipFile(root/'astracct-0.9.0-macos-universal.zip') as app:
                info=plistlib.loads(app.read('Astracct.app/Contents/Info.plist'))
                assert info['CFBundleIdentifier']=='com.yuashie.astracct' and info['CFBundleShortVersionString']=='0.9.0' and info['CFBundleVersion']=='12'
                # Confirm packaged executable architecture rather than guessing from runner.
                binary=app.read('Astracct.app/Contents/MacOS/Astracct')
                assert binary[:4]==bytes.fromhex('cafebabe')
                count=struct.unpack_from('>I',binary,4)[0]
                assert {struct.unpack_from('>I',binary,8+20*i)[0] for i in range(count)}=={0x1000007,0x100000c}, 'Expected Intel + Apple Silicon universal executable'
build_tools=sorted(pathlib.Path(os.environ['ANDROID_HOME'],'build-tools').glob('*'))[-1]
subprocess.run(['python3','scripts/inspect-android-apks.py','--directory','android-release','--aapt',str(build_tools/'aapt'),'--zipalign',str(build_tools/'zipalign'),'--version','0.9.0','--build-number','12'],check=True)
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
