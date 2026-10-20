#!/usr/bin/env python3
"""Set Astracct's stable Android applicationId after Flutter regenerates Gradle files."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
candidates = [
    ROOT / "apps/client/android/app/build.gradle.kts",
    ROOT / "apps/client/android/app/build.gradle",
]
path = next((p for p in candidates if p.exists()), None)
if path is None:
    raise SystemExit("Android app Gradle file not found; run flutter create first.")

text = path.read_text()
target = "com.yuashie.astracct"
patterns = [
    r'(applicationId\s*=\s*")[^"]+(")',
    r'(applicationId\s+")[^"]+(")',
]
updated = text
for pattern in patterns:
    updated, count = re.subn(pattern, rf'\1{target}\2', updated, count=1)
    if count:
        break
else:
    raise SystemExit("applicationId not found in Android app Gradle file.")

path.write_text(updated)

check = path.read_text()
if target not in check:
    raise SystemExit("Failed to configure Astracct applicationId.")
print(f"Android applicationId: {target}")

# local_auth 3 requires Android 24+ and an AppCompat launch theme.
text = path.read_text()
text = re.sub(r'minSdk\s*=\s*[^\n]+', 'minSdk = 24', text)
text = re.sub(r'minSdkVersion\s+[^\n]+', 'minSdkVersion 24', text)
path.write_text(text)
for style in (ROOT / 'apps/client/android/app/src/main/res').glob('values*/styles.xml'):
    style.write_text(style.read_text().replace('@android:style/Theme.Light.NoTitleBar', 'Theme.AppCompat.DayNight.NoActionBar')
        .replace('@android:style/Theme.Black.NoTitleBar', 'Theme.AppCompat.DayNight.NoActionBar'))
