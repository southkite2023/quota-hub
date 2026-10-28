#!/bin/bash
# Usage: build-dmg.sh /path/to/Astracct.app /path/to/output.dmg
set -euo pipefail
if [[ $# != 2 || ! -d "$1/Contents" || "$2" != *.dmg ]]; then
  echo 'Usage: build-dmg.sh Astracct.app output.dmg' >&2
  exit 1
fi
app=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
mkdir -p "$(dirname "$2")"
output=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
[[ ! -e "$output" ]] || { echo "Output already exists: $output" >&2; exit 1; }
scripts=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
mounted=false
cleanup() {
  if $mounted; then hdiutil detach "$work/mount" -quiet || true; fi
  rm -rf "$work"
}
trap cleanup EXIT
mkdir -p "$work/stage/.background" "$work/mount"
ditto "$app" "$work/stage/Astracct.app"
ln -s /Applications "$work/stage/Applications"
swift "$scripts/dmg-background.swift" "$work/stage/.background/install.png"
hdiutil create -quiet -volname '星账 Astracct' -srcfolder "$work/stage" \
  -fs HFS+ -format UDRW "$work/install.dmg"
hdiutil attach -quiet -nobrowse -mountpoint "$work/mount" "$work/install.dmg"
mounted=true
# Save Finder's layout in the image, including the hidden background asset.
osascript - "$work/mount" <<'APPLESCRIPT'
on run argv
  set volumePath to item 1 of argv
  tell application "Finder"
    set installFolder to (POSIX file volumePath) as alias
    open installFolder
    set installWindow to container window of installFolder
    set current view of installWindow to icon view
    set toolbar visible of installWindow to false
    set statusbar visible of installWindow to false
    set bounds of installWindow to {120, 100, 840, 560}
    set options to icon view options of installWindow
    set arrangement of options to not arranged
    set icon size of options to 96
    set text size of options to 14
    set background picture of options to file ".background:install.png" of installFolder
    set position of item "Astracct.app" of installFolder to {195, 230}
    set position of item "Applications" of installFolder to {525, 230}
    close installWindow
    open installFolder
    update installFolder without registering applications
    delay 2
    close container window of installFolder
  end tell
end run
APPLESCRIPT
[[ -f "$work/mount/.DS_Store" ]] || { echo 'Finder did not save the installation layout.' >&2; exit 1; }
sync
hdiutil detach -quiet "$work/mount"
mounted=false
hdiutil convert -quiet "$work/install.dmg" -format UDZO -o "$output"
hdiutil verify "$output"
echo "Created: $output"
