#!/usr/bin/env bash
# Builds a universal (Apple silicon + Intel), ad-hoc signed Havus.app and packs it
# as build/release/Havus-<version>.zip plus a SHA-256 checksum file.
#
# Usage: scripts/build-release.sh <version> [build-number]
#
# No certificates or secrets are involved. Once there is a Developer ID certificate,
# this is the place to add signing and notarization (see docs/maintainer.md).
set -euo pipefail

VERSION="${1:?Usage: scripts/build-release.sh <version> [build-number], e.g. 0.1.0}"
BUILD_NUMBER="${2:-1}"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must look like X.Y.Z (e.g. 0.1.0), got: $VERSION" >&2
  exit 1
fi
if ! [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Build number must be numeric, got: $BUILD_NUMBER" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/release"
ARCHIVE="$OUT/Havus.xcarchive"
ZIP="Havus-$VERSION.zip"

rm -rf "$OUT"
mkdir -p "$OUT"

xcodebuild archive \
  -project "$ROOT/Havus.xcodeproj" \
  -scheme Havus \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  -quiet

APP="$ARCHIVE/Products/Applications/Havus.app"
codesign --verify --strict "$APP"
echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/Havus")"

cd "$OUT"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP" > "$ZIP.sha256"
echo "Done: build/release/$ZIP"
cat "$ZIP.sha256"
