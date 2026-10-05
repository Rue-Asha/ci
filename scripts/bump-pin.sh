#!/usr/bin/env bash
# Usage: bump-pin.sh <file> <variable> <tag>
# Sets "<variable>: <tag>" in <file> (quotes and trailing comment kept) and prints changed, unchanged or
# skipped (pre-release, or older than the pinned version) and never moves the pin down.

set -euo pipefail

file=$1 variable=$2 tag=$3

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

if ! perl -ne 'BEGIN { $f = 1 } $f = 0 if /^\Q$ENV{BUMP_VAR}\E:\h/; END { exit $f }' "$file"; then
  echo "bump-pin: $file: $variable not found" >&2
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
version_re='^v?([0-9]+)\.([0-9]+)\.([0-9]+)$'
for v in "$pinned" "$tag"; do
  if [[ ! $v =~ $version_re ]]; then
    echo "bump-pin: $file: $variable: $v is not a version (vMAJOR.MINOR.PATCH)" >&2
    exit 1
  fi
done
[[ $pinned =~ $version_re ]] && pin_parts=("${BASH_REMATCH[@]:1}")
[[ $tag =~ $version_re ]] && tag_parts=("${BASH_REMATCH[@]:1}")
for i in 0 1 2; do
  if ((10#${tag_parts[i]} < 10#${pin_parts[i]})); then
    echo "skipped: $tag is older than the pinned $pinned"
    exit 0
  elif ((10#${tag_parts[i]} > 10#${pin_parts[i]})); then
    break
  fi
done

new=$(mktemp)
trap 'command rm -f "$new"' EXIT
perl -pe "$rewrite" "$file" >"$new"

if cmp -s "$file" "$new"; then
  echo unchanged
  exit 0
fi

cat "$new" >"$file"
echo changed
