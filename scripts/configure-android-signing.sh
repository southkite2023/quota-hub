#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v gh >/dev/null || { echo '请先安装 GitHub CLI：brew install gh'; exit 1; }
gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --web --git-protocol https
store='private/android-signing/quota-hub-release.p12'
password='private/android-signing/store-password.txt'
test -f "$store" && test -f "$password" || { echo '本机签名备份缺失，请勿重新生成替代密钥。'; exit 1; }
# Pipe directly to GitHub CLI: never print private key or password, never commit either.
base64 < "$store" | gh secret set ANDROID_SIGNING_STORE_BASE64 --repo southkite2023/quota-hub
gh secret set ANDROID_SIGNING_PASSWORD --repo southkite2023/quota-hub < "$password"
echo '两项签名密钥已加密保存至 GitHub Actions Secrets。请离线备份 private/android-signing 整个目录。'
