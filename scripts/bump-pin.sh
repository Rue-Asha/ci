#!/usr/bin/env bash
# Usage: bump-pin.sh <file> <variable> <tag>
# Sets "<variable>: <tag>" in <file> and prints changed, unchanged or skipped.

set -euo pipefail

file=$1 variable=$2 tag=$3

# A pre-release is never deployed.
if [[ $tag == *-* ]]; then
  echo skipped
  exit 0
fi

if ! grep -q "^${variable}: " "$file"; then
  echo "bump-pin: $file: $variable not found" >&2
  exit 1
fi

if grep -qx "${variable}: ${tag}" "$file"; then
  echo unchanged
  exit 0
fi

sed -i "s|^\(${variable}: \).*|\1${tag}|" "$file"
echo changed
