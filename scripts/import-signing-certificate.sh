#!/usr/bin/env bash
# Imports the Havus release certificate into a new keychain, so scripts/build-release.sh can sign with it.
#
# Usage:
#   HAVUS_SIGNING_P12_BASE64=... HAVUS_SIGNING_P12_PASSWORD=... \
#     scripts/import-signing-certificate.sh <new-keychain-path>
#
# The Release workflow runs it with values from GitHub secrets. A maintainer can run it with the
# backup from the password manager to sign a release locally. It prints nothing secret.
# Delete the keychain when you're done: security delete-keychain <new-keychain-path>
set -euo pipefail

KEYCHAIN="${1:?Usage: scripts/import-signing-certificate.sh <new-keychain-path>}"
: "${HAVUS_SIGNING_P12_BASE64:?HAVUS_SIGNING_P12_BASE64 isn't set}"
: "${HAVUS_SIGNING_P12_PASSWORD:?HAVUS_SIGNING_P12_PASSWORD isn't set}"

if [[ -e "$KEYCHAIN" ]]; then
  echo "$KEYCHAIN already exists. Choose a new path." >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
printf '%s' "$HAVUS_SIGNING_P12_BASE64" | base64 --decode > "$work/signing.p12"

# create-keychain also adds the keychain to the user's search list. Put the list back afterwards:
# build-release.sh names the keychain explicitly, and nothing else should find this certificate.
search_list="$(security list-keychains -d user)"
keychain_password="$(uuidgen)"
security create-keychain -p "$keychain_password" "$KEYCHAIN"
printf '%s\n' "$search_list" | xargs security list-keychains -d user -s

security set-keychain-settings -lut 3600 "$KEYCHAIN"
security unlock-keychain -p "$keychain_password" "$KEYCHAIN"
security import "$work/signing.p12" -k "$KEYCHAIN" -P "$HAVUS_SIGNING_P12_PASSWORD" -T /usr/bin/codesign >/dev/null
# Lets codesign use the key without a password prompt.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$KEYCHAIN" >/dev/null

echo "Imported the Havus release certificate into $KEYCHAIN."
