#!/usr/bin/env bash
set -euo pipefail
: "${ANDROID_SIGNING_STORE_BASE64:?缺少固定签名密钥，拒绝发布临时签名包}"
: "${ANDROID_SIGNING_PASSWORD:?缺少固定签名密码，拒绝发布}"
input=${1:?Usage: sign-android-apk.sh input.apk output.apk}
output=${2:?Usage: sign-android-apk.sh input.apk output.apk}
repo_root=$(cd "$(dirname "$0")/.." && pwd)
signing_dir=$(mktemp -d)
trap 'rm -rf "$signing_dir"' EXIT
umask 077
printf '%s' "$ANDROID_SIGNING_STORE_BASE64" | base64 --decode > "$signing_dir/store.p12"
signer=$(find "${ANDROID_HOME:?}/build-tools" -name apksigner -type f | sort -V | tail -1)
"$signer" sign --ks "$signing_dir/store.p12" --ks-key-alias quota-hub --ks-pass env:ANDROID_SIGNING_PASSWORD --out "$output" "$input"
"$signer" verify --verbose --print-certs "$output" | tee "$signing_dir/certificate.txt"
# Different build-tools versions include SDK ranges before the signer number.
actual=$(sed -n 's/^Signer.*certificate SHA-256 digest: //p' "$signing_dir/certificate.txt" | tr '[:upper:]' '[:lower:]' | tr -d '\r' | sort -u)
expected=$(tr -d '\r\n' < "$repo_root/docs/ANDROID_SIGNING_SHA256.txt")
test "$actual" = "$expected" || { echo "签名证书不一致，拒绝发布；实际公开指纹：$actual；预期：$expected"; exit 1; }
echo "固定签名验证通过：$actual"
