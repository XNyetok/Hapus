#!/bin/sh
# Checks that every UI string in the code is in Havus/Localizable.xcstrings, with an English translation.
#
# Run it after a Debug build (make build): the compiler lists the strings it finds in .stringsdata files.
#   scripts/check-strings.sh           check a synced copy and leave the catalog alone (CI)
#   scripts/check-strings.sh --write   also add new strings to the catalog and mark unused ones stale (make strings)
set -eu
cd "$(dirname "$0")/.."

CATALOG=Havus/Localizable.xcstrings

if [ "${1:-}" = "--write" ]; then
  target=$CATALOG
else
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  # xcstringstool matches strings to a catalog by its file name, so the copy keeps it.
  target=$tmp/Localizable.xcstrings
  cp "$CATALOG" "$target"
fi

set -- build/DerivedData/Build/Intermediates.noindex/Havus.build/Debug/Havus.build/Objects-normal/*/*.stringsdata
if [ ! -e "$1" ]; then
  echo "No .stringsdata files in build/DerivedData. Build first: make build" >&2
  exit 1
fi

xcrun xcstringstool sync "$target" --stringsdata "$@"
swift scripts/check-strings.swift "$target"
