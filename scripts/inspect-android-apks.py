#!/usr/bin/env python3
"""Validate distribution APK metadata, alignment and payload; emit size evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--directory', type=Path, required=True)
parser.add_argument('--aapt', required=True)
parser.add_argument('--zipalign', required=True)
parser.add_argument('--version', required=True)
parser.add_argument('--build-number', required=True)
args = parser.parse_args()
expected_abis = {
    'universal': {'armeabi-v7a', 'arm64-v8a', 'x86_64'},
    'armeabi-v7a': {'armeabi-v7a'}, 'arm64-v8a': {'arm64-v8a'}, 'x86_64': {'x86_64'},
}
results = []
for variant, abis in expected_abis.items():
    path = args.directory / f'quota-hub-{args.version}-{variant}.apk'
    badging = subprocess.check_output([args.aapt, 'dump', 'badging', str(path)], text=True)
    package = re.search(r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging, re.M)
    assert package and package.groups() == ('com.example.quota_hub', args.build_number, args.version), badging
    assert 'application-debuggable' not in badging, 'Debuggable APK is not distributable'
    subprocess.run([args.zipalign, '-c', '-P', '16', '4', str(path)], check=True)
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        actual_abis = {n.split('/')[1] for n in names if n.startswith('lib/') and n.endswith('.so')}
        assert actual_abis == abis, (variant, actual_abis)
        assert not any(n.endswith(('kernel_blob.bin', 'vm_snapshot_data', 'isolate_snapshot_data')) for n in names), 'Debug Dart payload found'
        for abi in abis:
            assert f'lib/{abi}/libapp.so' in names, 'Missing AOT app library'
            assert f'lib/{abi}/libflutter.so' in names, 'Missing Flutter engine'
        for name in names:
            if not name.startswith(('lib/arm64-v8a/', 'lib/x86_64/')) or not name.endswith('.so'):
                continue
            blob = archive.read(name)
            assert blob[:6] == b'\x7fELF\x02\x01', 'Expected little-endian ELF64'
            offset = struct.unpack_from('<Q', blob, 32)[0]
            entry_size, count = struct.unpack_from('<HH', blob, 54)
            loads = [struct.unpack_from('<IIQQQQQQ', blob, offset + i * entry_size) for i in range(count)]
            assert all(p[7] >= 16384 for p in loads if p[0] == 1), f'ELF alignment below 16 KB: {name}'
        groups = {}
        for item in archive.infolist():
            key = '/'.join(item.filename.split('/')[:2]) if item.filename.startswith('lib/') else item.filename.split('/')[0]
            group = groups.setdefault(key, {'compressed_bytes': 0, 'uncompressed_bytes': 0})
            group['compressed_bytes'] += item.compress_size
            group['uncompressed_bytes'] += item.file_size
        results.append({'file': path.name, 'bytes': path.stat().st_size,
                        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                        'abis': sorted(actual_abis), 'debuggable': False,
                        'version': args.version, 'version_code': args.build_number,
                        'zip_16kb_alignment': True, 'elf_16kb_alignment': True,
                        'groups': groups})
(args.directory / 'apk-report.json').write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n')
(args.directory / 'SHA256SUMS.txt').write_text(''.join(f"{r['sha256']}  {r['file']}\n" for r in results))
print(json.dumps(results, ensure_ascii=False, indent=2))
