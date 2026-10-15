#!/bin/sh
set -eu
archive=$1
target=$2
old_pid=$3
version=$4
case "$target" in /*.app) ;; *) exit 1;; esac
case "$old_pid" in ''|*[!0-9]*) exit 1;; esac
[ -d "$target/Contents" ] && [ ! -L "$target" ]
plist=/usr/libexec/PlistBuddy
[ "$("$plist" -c 'Print CFBundleIdentifier' "$target/Contents/Info.plist")" = com.yuashie.astracct ]
parent=$(dirname "$target")
stage=$(mktemp -d "$parent/.astracct-update-XXXXXXXX")
backup="$target.previous-$(date +%Y%m%d%H%M%S)-$$"
switched=false
cleanup() {
  status=$?
  if [ "$status" -ne 0 ] && [ "$switched" = true ] && [ -d "$backup" ]; then
    [ ! -e "$target" ] || mv "$target" "$stage/failed.app"
    mv "$backup" "$target"
    /usr/bin/open "$target" || true
  fi
  rm -rf "$stage"
}
trap cleanup EXIT
# Reject absolute and parent-traversing archive paths before extracting a verified ZIP.
/usr/bin/unzip -Z1 "$archive" > "$stage/entries"
if /usr/bin/grep -Eq '(^/|(^|/)\.\.(/|$)|\\)' "$stage/entries"; then exit 1; fi
/usr/bin/ditto -x -k "$archive" "$stage/unpacked"
app="$stage/unpacked/Astracct.app"
[ -x "$app/Contents/MacOS/Astracct" ]
[ "$("$plist" -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")" = com.yuashie.astracct ]
[ "$("$plist" -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")" = "$version" ]
printf 'READY\n'
count=0
while kill -0 "$old_pid" 2>/dev/null; do
  count=$((count + 1))
  [ "$count" -lt 120 ] || exit 1
  sleep 1
done
mv "$target" "$backup"
switched=true
mv "$app" "$target"
/usr/bin/open "$target"
