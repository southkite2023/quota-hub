#!/bin/bash
set -euo pipefail
cd linux-dist
sha256sum -c SHA256SUMS-*.txt
mkdir extracted
for f in *.deb; do dpkg-deb -x "$f" extracted/deb; done
for f in *.rpm; do rpm2cpio "$f" | (cd extracted; mkdir rpm; cd rpm; cpio -idm --quiet); done
for f in *.tar.gz; do mkdir -p extracted/tar; tar -xzf "$f" -C extracted/tar; done
for f in *.AppImage; do chmod +x "$f"; "$PWD/$f" --appimage-extract >/dev/null; done
cmp extracted/deb/opt/astracct/astracct extracted/rpm/opt/astracct/astracct
cmp extracted/deb/opt/astracct/astracct extracted/tar/astracct
cmp extracted/deb/opt/astracct/astracct squashfs-root/usr/lib/astracct/astracct
expected=$(uname -m)
file extracted/tar/astracct | tee elf.txt
if [ "$expected" = x86_64 ]; then grep -q 'x86-64' elf.txt; else grep -q 'aarch64' elf.txt; fi
cat > smoke.sh <<'INNER'
#!/bin/bash
set -euo pipefail
openbox >openbox.log 2>&1 &
wm=$!
"$1" >"$2.log" 2>&1 &
app=$!
trap 'kill "$app" "$wm" 2>/dev/null || true' EXIT
sleep 10
kill -0 "$app"
xdotool search --onlyvisible --pid "$app" >"$2.windows"
test -s "$2.windows"
import -window root "$2.png"
! grep -Ei 'Unhandled Exception|error while loading shared libraries|Segmentation fault' "$2.log"
INNER
chmod +x smoke.sh
dbus-run-session -- xvfb-run -a ./smoke.sh "$PWD/extracted/tar/astracct" tar-launch
dbus-run-session -- xvfb-run -a ./smoke.sh "$PWD/squashfs-root/AppRun" appimage-launch
