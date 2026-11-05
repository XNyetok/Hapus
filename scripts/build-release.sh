#!/usr/bin/env bash
# Builds a universal (Apple silicon + Intel) Havus.app and packs it as
# build/release/Havus-<version>.zip plus a SHA-256 checksum file.
#
# Usage: scripts/build-release.sh <version> [build-number]
#
# Signing: when HAVUS_SIGNING_KEYCHAIN points to a keychain that holds the Havus release
# certificate, the app is signed with it. The Release workflow imports that certificate from
# GitHub secrets. macOS ties Full Disk Access to this signature, so users keep the permission
# when they update. Without HAVUS_SIGNING_KEYCHAIN the app stays ad-hoc signed, which is fine
# for testing but makes macOS treat every build as a new app. See docs/maintainer.md.
set -euo pipefail

# SHA-1 of the Havus release certificate. Every release must be signed with this certificate:
# a different one takes Full Disk Access away from every user, so signing fails if it doesn't match.
RELEASE_CERT_SHA1=9e4a60cb751d37f504f5290a9ead326f31e739b5
RELEASE_REQUIREMENT="identifier \"id.nyetok.havus\" and certificate leaf = H\"$RELEASE_CERT_SHA1\""

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

if [[ -n "${HAVUS_SIGNING_KEYCHAIN:-}" ]]; then
  # The app has no nested code yet. A future helper or framework must be signed with the same
  # certificate before the app itself.
  codesign --force --options runtime --timestamp=none --preserve-metadata=entitlements \
    --keychain "$HAVUS_SIGNING_KEYCHAIN" \
    --sign "$RELEASE_CERT_SHA1" \
    --requirements "=designated => $RELEASE_REQUIREMENT" \
    "$APP"
  codesign --verify --strict --test-requirement "=$RELEASE_REQUIREMENT" "$APP"
  echo "Signed with the Havus release certificate ($RELEASE_CERT_SHA1)."
else
  echo "HAVUS_SIGNING_KEYCHAIN isn't set, so this build stays ad-hoc signed: fine for testing, not for a release." >&2
fi

codesign --verify --strict "$APP"
echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/Havus")"

cd "$OUT"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP" > "$ZIP.sha256"
echo "Done: build/release/$ZIP"
cat "$ZIP.sha256"
