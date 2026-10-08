#!/usr/bin/env python3
"""Apply stable desktop identity and outbound network permissions to generated runners."""
from pathlib import Path
import plistlib
import re

ROOT = Path(__file__).resolve().parents[1] / 'apps/client'
mac = ROOT / 'macos/Runner'
if mac.is_dir() and (mac / 'Configs/AppInfo.xcconfig').exists():
    info = mac / 'Configs/AppInfo.xcconfig'
    text = info.read_text()
    for key, value in [('PRODUCT_NAME', 'Astracct'), ('PRODUCT_BUNDLE_IDENTIFIER', 'com.yuashie.astracct')]:
        text, count = re.subn(rf'^{key}\s*=.*$', f'{key} = {value}', text, flags=re.M)
        if count != 1:
            raise SystemExit(f'Expected one {key} in macOS runner')
    info.write_text(text)
    for name in ['DebugProfile.entitlements', 'Release.entitlements']:
        path = mac / name
        entitlements = plistlib.loads(path.read_bytes())
        entitlements['com.apple.security.network.client'] = True
        # The desktop vault uses the legacy Keychain: no shared access group or provisioning profile.
        path.write_bytes(plistlib.dumps(entitlements))
    (mac / 'MainFlutterWindow.swift').write_text((ROOT.parents[1] / 'scripts/macos/MainFlutterWindow.swift').read_text())
    (mac / 'AppDelegate.swift').write_text((ROOT.parents[1] / 'scripts/macos/AppDelegate.swift').read_text())
    print('macOS identity and outbound network permission configured')

windows = ROOT / 'windows'
if (windows / 'CMakeLists.txt').exists():
    path = windows / 'CMakeLists.txt'
    text, count = re.subn(r'set\(BINARY_NAME "[^"]+"\)', 'set(BINARY_NAME "astracct")', path.read_text())
    if count != 1:
        raise SystemExit('Expected one Windows BINARY_NAME')
    path.write_text(text)
    print('Windows executable: astracct.exe')
