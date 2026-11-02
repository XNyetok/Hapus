#!/usr/bin/env bash
# Prepares a fresh clone for development. Safe to run more than once.
set -euo pipefail
cd "$(dirname "$0")/.."

git config core.hooksPath .githooks
echo "✓ Git hooks enabled (.githooks): sensitive files and secrets are checked before each commit"

if command -v gitleaks >/dev/null 2>&1; then
  echo "✓ gitleaks $(gitleaks version)"
else
  echo "! gitleaks is not installed. Recommended: brew install gitleaks"
fi

if xcodebuild -version >/dev/null 2>&1; then
  echo "✓ $(xcodebuild -version | head -1)"
else
  echo "! Xcode is not installed or not selected (xcode-select -s /Applications/Xcode.app)"
fi

if [ ! -f Config/Local.xcconfig ]; then
  echo "i Optional: cp Config/Local.xcconfig.example Config/Local.xcconfig"
  echo "  so Full Disk Access doesn't reset on every build (see CONTRIBUTING.md)."
fi
