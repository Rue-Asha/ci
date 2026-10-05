#!/usr/bin/env bash
# Usage: bump-pin.sh <file> <variable> <tag>
# Sets "<variable>: <tag>" in <file> (quotes and trailing comment kept) and prints changed, unchanged or
# skipped (pre-release, or older than the pinned version) and never moves the pin down.

set -euo pipefail

file=$1 variable=$2 tag=$3

# shellcheck source=version.sh
source "$(dirname "${BASH_SOURCE[0]}")/version.sh"

# The tag becomes a plain YAML scalar, so nothing that YAML would read as
# a comment, quote, flow indicator or key separator may be in it.
if [[ $tag == *[[:space:]\#\"\'{}\[\],\\]* || $tag == *: ]]; then
  echo "bump-pin: $tag: not a safe YAML scalar" >&2
  exit 1
fi

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

# Ansible takes the last of two keys while a rewrite of only the first would
# leave it pinned, so a repeated key is an error rather than a guess.
count=$(perl -ne '$n++ if /^\Q$ENV{BUMP_VAR}\E:\h/; END { print $n + 0 }' "$file")
if [ "$count" -eq 0 ]; then
  echo "bump-pin: $file: $variable not found" >&2
  exit 1
elif [ "$count" -gt 1 ]; then
  echo "bump-pin: $file: $variable is set more than once" >&2
  exit 1
fi

# The rewrite only understands a bare or simply quoted token; anything else
# (empty, templated, comment only) would be left alone and reported unchanged.
valid='^\Q$ENV{BUMP_VAR}\E:\h+(?:"[^"\\]+"|\x27[^\x27\\]+\x27|[^\s"\x27#{}\[\],&*!|>%@`:][^\s"\x27#]*)(?:\h+#.*|\h*)$'
if ! perl -ne "next unless /^\\Q\$ENV{BUMP_VAR}\\E:\\h/; \$bad = 1 unless /$valid/; END { exit \$bad ? 1 : 0 }" "$file"; then
  echo "bump-pin: $file: $variable has no plain or quoted value" >&2
  exit 1
fi

# The pin only moves upward: compare as vMAJOR.MINOR.PATCH, numerically.
pinned=$(perl -ne 'if (/^\Q$ENV{BUMP_VAR}\E:\h+(["\x27]?)([^"\x27\s#]+)\1/) { print $2; exit }' "$file")
for v in "$pinned" "$tag"; do
  if [[ ! $v =~ $version_re ]]; then
    echo "bump-pin: $file: $variable: $v is not a version (vMAJOR.MINOR.PATCH)" >&2
    exit 1
  fi
done
if version_older "$tag" "$pinned"; then
  echo "skipped: $tag is older than the pinned $pinned"
  exit 0
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
