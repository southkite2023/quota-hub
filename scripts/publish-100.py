"""One-time publication of the immutable, validated Android 1.0.0 candidate."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile

REPO = 'repos/southkite2023/quota-hub'
SOURCE = '1cbe0df37a191be8dbed935dc40f0464710549a5'
NATIVE_RUN = 37865301946
ARTIFACT = 11588405711
DIGEST = '3ddf32c6427e536dc7fd934031375e15af668ec033d1d8f6d64a1b474ce586c8'

def api(path):
    return json.loads(subprocess.check_output(['gh', 'api', path]))

for run_id in [NATIVE_RUN, 37865301884, 37865301931]:
    run = api(f'{REPO}/actions/runs/{run_id}')
    assert run['conclusion'] == 'success' and run['head_sha'] == SOURCE
assert api(f'{REPO}/pulls/16')['merged']
# The release source must be contained in main; publication cannot replace concurrent changes.
comparison = api(f'{REPO}/compare/{SOURCE}...main')
assert comparison['status'] in {'ahead', 'identical'}
artifacts = {a['id']: a for a in api(f'{REPO}/actions/runs/{NATIVE_RUN}/artifacts')['artifacts']}
artifact = artifacts[ARTIFACT]
assert artifact['name'] == 'quota-hub-android-signed' and not artifact['expired']
assert artifact['workflow_run']['head_sha'] == SOURCE
assert artifact['digest'] == f'sha256:{DIGEST}'
blob = subprocess.check_output(['gh', 'api', f'{REPO}/actions/artifacts/{ARTIFACT}/zip'])
assert hashlib.sha256(blob).hexdigest() == DIGEST
archive = Path('android-candidate.zip'); archive.write_bytes(blob)
variants = ['universal', 'arm64-v8a', 'armeabi-v7a', 'x86_64']
apks = {f'quota-hub-1.0.0-{abi}.apk' for abi in variants}
allowed = apks | {f'{name}.idsig' for name in apks} | {'SHA256SUMS.txt', 'apk-report.json'}
with zipfile.ZipFile(archive) as z:
    assert set(z.namelist()) == allowed and z.testzip() is None
    z.extractall('android-release')
for line in Path('android-release/SHA256SUMS.txt').read_text().splitlines():
    digest, name = line.split()
    assert name in apks
    assert hashlib.sha256(Path('android-release', name).read_bytes()).hexdigest() == digest
build_tools = sorted(Path(os.environ['ANDROID_HOME'], 'build-tools').glob('*'),
                     key=lambda p: tuple(int(n) for n in re.findall(r'\d+', p.name)))[-1]
subprocess.run(['python3', 'scripts/inspect-android-apks.py', '--directory', 'android-release',
                '--aapt', str(build_tools / 'aapt'), '--zipalign', str(build_tools / 'zipalign'),
                '--version', '1.0.0', '--build-number', '14'], check=True)
cert = Path('docs/ANDROID_SIGNING_SHA256.txt').read_text().strip()
assert cert == '46b9dc0f50187f7fd127e1bd962ba90384d270c02ccaf2b2e093213ab50f907b'
root = Path('release'); root.mkdir()
report = json.loads(Path('android-release/apk-report.json').read_text())
for item in report:
    src = Path('android-release', item['file'])
    output = subprocess.check_output([str(build_tools / 'apksigner'), 'verify', '--print-certs', str(src)], text=True)
    fingerprints = {m.lower() for m in re.findall(r'Signer.*certificate SHA-256 digest: ([0-9a-fA-F]+)', output)}
    assert fingerprints == {cert}, 'Fixed certificate mismatch'
    name = item['file'].replace('-universal.apk', '-android.apk')
    (root / name).write_bytes(src.read_bytes())
    item['file'] = name
(root / 'apk-report.json').write_text(json.dumps(report, indent=2) + '\n')
manifest = [{'file': p.name, 'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
            for p in sorted(root.glob('*.apk'))]
(root / 'packages.json').write_text(json.dumps(manifest, indent=2) + '\n')
(root / 'SHA256SUMS.txt').write_text(''.join(f"{p['sha256']}  {p['file']}\n" for p in manifest))
print(json.dumps(manifest, indent=2))
