#!/usr/bin/env bash
# Usage: bump-pin.sh <file> <variable> <tag>
# Sets "<variable>: <tag>" in <file> (quotes and trailing comment kept) and prints changed, unchanged or skipped.

set -euo pipefail

file=$1 variable=$2 tag=$3

# A pre-release is never deployed.
if [[ $tag == *-* ]]; then
  echo skipped
  exit 0
fi

if [ ! -f "$file" ]; then
  echo "bump-pin: $file: file not found" >&2
  exit 1
fi

# Tag and variable go in through the environment so no character in them is
# special to the substitution. Quotes and a trailing comment stay as they are.
export BUMP_VAR=$variable BUMP_TAG=$tag
rewrite='s/^(\Q$ENV{BUMP_VAR}\E:\h+)(["\x27]?)[^"\x27\s#]+\2/$1$2$ENV{BUMP_TAG}$2/'

if ! perl -ne 'BEGIN { $f = 1 } $f = 0 if /^\Q$ENV{BUMP_VAR}\E:\h/; END { exit $f }' "$file"; then
  echo "bump-pin: $file: $variable not found" >&2
  exit 1
fi

new=$(mktemp)
trap 'command rm -f "$new"' EXIT
perl -pe "$rewrite" "$file" >"$new"

if cmp -s "$file" "$new"; then
  echo unchanged
  exit 0
fi

cat "$new" >"$file"
echo changed
