#!/usr/bin/env bash
# Prepares a fresh clone for development. Safe to run more than once.
set -euo pipefail
cd "$(dirname "$0")/.."

git config core.hooksPath .githooks
echo "✓ Git hooks aktif (.githooks): file sensitif & secret dicek sebelum commit"

if command -v gitleaks >/dev/null 2>&1; then
  echo "✓ gitleaks $(gitleaks version)"
else
  echo "! gitleaks belum ke-install. Disarankan: brew install gitleaks"
fi

if xcodebuild -version >/dev/null 2>&1; then
  echo "✓ $(xcodebuild -version | head -1)"
else
  echo "! Xcode belum ke-install atau belum dipilih (xcode-select -s /Applications/Xcode.app)"
fi

if [ ! -f Config/Local.xcconfig ]; then
  echo "i Opsional: cp Config/Local.xcconfig.example Config/Local.xcconfig"
  echo "  biar izin Akses Disk Penuh nggak reset tiap build (lihat CONTRIBUTING.md)."
fi
