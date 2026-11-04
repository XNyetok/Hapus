#!/usr/bin/env bash
# Appends a snapshot of every published release asset's download count to a CSV file.
# GitHub keeps only the running total per asset, so the history exists only if it is
# recorded like this. Run it about once a week (see docs/maintainer.md).
#
# Usage: scripts/download-stats.sh [path/to/download-stats.csv]
#   Default file: ../Havus-stats/download-stats.csv, next to the repository folder.
#   It lives outside the repo on purpose: `make clean` deletes build/.
#   Environment: HAVUS_REPO (default XNyetok/Havus)
# Requires the GitHub CLI (gh), logged in.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${HAVUS_REPO:-XNyetok/Havus}"
FILE="${1:-$(dirname "$ROOT")/Havus-stats/download-stats.csv}"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if ! command -v gh >/dev/null 2>&1; then
  echo "error: GitHub CLI (gh) is not installed." >&2
  exit 1
fi

# One line per asset of every published release (drafts are skipped).
# gh runs the jq filter itself, so no separate jq install is needed.
# The jq filter stays single-quoted on purpose: $tag belongs to jq, not to the shell.
# shellcheck disable=SC2016
RAW="$(gh api --paginate "repos/$REPO/releases?per_page=100" --jq '
  .[] | select(.draft | not) | .tag_name as $tag | .assets[]
  | "\($tag),\(.name),\(.download_count)"')"

if [ -z "$RAW" ]; then
  echo "error: no published release assets found in $REPO." >&2
  exit 1
fi

# Every row gets the same timestamp. A name with a comma would break the CSV, so stop instead.
ROWS="$(printf '%s\n' "$RAW" | awk -v now="$NOW" -F, '
  NF != 3 { print "error: asset or tag name contains a comma: " $0 > "/dev/stderr"; exit 1 }
  { print now "," $0 }')"

# Compare each asset with its previous snapshot, then append the new rows.
echo "Snapshot $NOW -> $FILE"
printf '%s\n' "$ROWS" | awk -v prev="$FILE" -F, '
  BEGIN {
    while ((getline line < prev) > 0) {
      n = split(line, f, ",")
      if (n == 4 && f[4] ~ /^[0-9]+$/) {
        last[f[2] "," f[3]] = f[4]
        when[f[2] "," f[3]] = substr(f[1], 1, 10)
      }
    }
    close(prev)
  }
  {
    key = $2 "," $3
    if (key in last) printf "  %-8s %-28s %6d  (%+d since %s)\n", $2, $3, $4, $4 - last[key], when[key]
    else printf "  %-8s %-28s %6d  (first record)\n", $2, $3, $4
  }'

mkdir -p "$(dirname "$FILE")"
if [ ! -s "$FILE" ]; then
  echo "recorded_at_utc,tag,asset,download_count" > "$FILE"
fi
printf '%s\n' "$ROWS" >> "$FILE"
echo "Recorded $(printf '%s\n' "$ROWS" | wc -l | tr -d ' ') rows."
