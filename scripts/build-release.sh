#!/usr/bin/env bash
# Builds a universal (Apple Silicon + Intel), ad-hoc signed Hapus.app and packs it
# as build/release/Hapus-<version>.zip plus a SHA-256 checksum file.
#
# Usage: scripts/build-release.sh <version> [build-number]
#
# No certificates or secrets are involved. Once there is a Developer ID certificate,
# this is the place to add signing + notarization (see docs/maintainer.md).
set -euo pipefail

VERSION="${1:?Pakai: scripts/build-release.sh <versi> [nomor-build], contoh 0.1.0}"
BUILD_NUMBER="${2:-1}"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Versi harus format X.Y.Z (contoh 0.1.0), bukan: $VERSION" >&2
  exit 1
fi
if ! [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Nomor build harus angka, bukan: $BUILD_NUMBER" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/release"
ARCHIVE="$OUT/Hapus.xcarchive"
ZIP="Hapus-$VERSION.zip"

rm -rf "$OUT"
mkdir -p "$OUT"

xcodebuild archive \
  -project "$ROOT/Hapus.xcodeproj" \
  -scheme Hapus \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  -quiet

APP="$ARCHIVE/Products/Applications/Hapus.app"
codesign --verify --strict "$APP"
echo "Arsitektur: $(lipo -archs "$APP/Contents/MacOS/Hapus")"

cd "$OUT"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP" > "$ZIP.sha256"
echo "Selesai: build/release/$ZIP"
cat "$ZIP.sha256"
