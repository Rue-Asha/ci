#!/usr/bin/env bash
# Fixture tests for scripts/bump-pin.sh, one per unit-proofed scenario of the
# release-bump spec.

set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 1

dir=$(mktemp -d)
trap 'command rm -rf "$dir"' EXIT

fail=0
check() {
  if [ "$2" = "$3" ]; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    printf '  want: %s\n  got:  %s\n' "$2" "$3"
    fail=1
  fi
}

fixture() {
  printf '%s\n' '---' 'life_manager_version: v0.2.0' 'life_manager_port: 3000' 'other_version: v0.2.0' >"$dir/vars.yml"
}

run() {
  out=$(bash scripts/bump-pin.sh "$dir/vars.yml" "$@" 2>"$dir/err")
  rc=$?
  err=$(<"$dir/err")
}

fixture
cp "$dir/vars.yml" "$dir/before.yml"
run life_manager_version v0.3.0
check "Scenario: A new tag is bumped (stdout)" "changed" "$out"
check "Scenario: A new tag is bumped (exit)" "0" "$rc"
check "Scenario: A new tag is bumped (diff)" "2c2" "$(diff "$dir/before.yml" "$dir/vars.yml" | head -n1)"
check "Scenario: A new tag is bumped (line)" "life_manager_version: v0.3.0" "$(sed -n 2p "$dir/vars.yml")"
check "Scenario: A new tag is bumped (rest)" "$(sed 1d "$dir/before.yml" | sed 1d)" "$(sed 1,2d "$dir/vars.yml")"

fixture
run absent_version v0.3.0
check "Scenario: The variable line is missing (exit)" "1" "$rc"
check "Scenario: The variable line is missing (stderr)" "bump-pin: $dir/vars.yml: absent_version not found" "$err"
check "Scenario: The variable line is missing (untouched)" "life_manager_version: v0.2.0" "$(sed -n 2p "$dir/vars.yml")"

fixture
cp "$dir/vars.yml" "$dir/before.yml"
run life_manager_version v0.2.0
check "Scenario: The value already equals the tag (stdout)" "unchanged" "$out"
check "Scenario: The value already equals the tag (exit)" "0" "$rc"
check "Scenario: The value already equals the tag (file)" "$(<"$dir/before.yml")" "$(<"$dir/vars.yml")"

fixture
cp "$dir/vars.yml" "$dir/before.yml"
run life_manager_version v1.2.3-rc1
check "Scenario: A pre-release tag is not bumped (stdout)" "skipped" "$out"
check "Scenario: A pre-release tag is not bumped (exit)" "0" "$rc"
check "Scenario: A pre-release tag is not bumped (file)" "$(<"$dir/before.yml")" "$(<"$dir/vars.yml")"

fixture
run life_manager_version 'v1&2|x'
check "Scenario: The line has quotes, a comment or special characters (literal tag)" "life_manager_version: v1&2|x" "$(sed -n 2p "$dir/vars.yml")"

printf '%s\n' '---' 'life_manager_version: v0.2.0  # note' 'life_manager_port: 3000' >"$dir/vars.yml"
run life_manager_version v0.3.0
check "Scenario: The line has quotes, a comment or special characters (trailing comment kept)" "life_manager_version: v0.3.0  # note" "$(sed -n 2p "$dir/vars.yml")"
run life_manager_version v0.3.0
check "Scenario: The value already equals the tag (trailing comment)" "unchanged" "$out"

printf '%s\n' '---' 'life_manager_version: "v0.2.0"' >"$dir/vars.yml"
run life_manager_version v0.3.0
check "Scenario: The line has quotes, a comment or special characters (double quotes kept)" 'life_manager_version: "v0.3.0"' "$(sed -n 2p "$dir/vars.yml")"
run life_manager_version v0.3.0
check "Scenario: The value already equals the tag (quoted)" "unchanged" "$out"

printf '%s\n' '---' "life_manager_version: 'v0.2.0'" >"$dir/vars.yml"
run life_manager_version v0.3.0
check "Scenario: The line has quotes, a comment or special characters (single quotes kept)" "life_manager_version: 'v0.3.0'" "$(sed -n 2p "$dir/vars.yml")"

fixture
run life_manager_version v1.2.3-rc1
run life_manager_version v0.2.0
check "Scenario: The value already equals the tag (stdout, 2nd)" "unchanged" "$out"

for bad in 'life_manager_version: ""' 'life_manager_version:   # c' 'life_manager_version: {{ x }}' "life_manager_version: ''" 'life_manager_version: "v0.2.0'; do
  printf '%s\n' '---' "$bad" >"$dir/vars.yml"
  cp "$dir/vars.yml" "$dir/before.yml"
  run life_manager_version v0.3.0
  check "Scenario: The value is not a plain or quoted token ($bad: exit)" "1" "$rc"
  check "Scenario: The value is not a plain or quoted token ($bad: stdout)" "" "$out"
  check "Scenario: The value is not a plain or quoted token ($bad: stderr)" "bump-pin: $dir/vars.yml: life_manager_version has no plain or quoted value" "$err"
  check "Scenario: The value is not a plain or quoted token ($bad: untouched)" "$(<"$dir/before.yml")" "$(<"$dir/vars.yml")"
done

for badtag in 'v1#x' 'v1"x' "v1'x" 'v1 x' 'v1{x' 'v1}x' 'v1[x' 'v1]x' 'v1,x' 'v1\x' 'v1:' 'v1: x'; do
  fixture
  cp "$dir/vars.yml" "$dir/before.yml"
  run life_manager_version "$badtag"
  check "Scenario: The tag is not a safe YAML scalar ($badtag: exit)" "1" "$rc"
  check "Scenario: The tag is not a safe YAML scalar ($badtag: stderr)" "bump-pin: $badtag: not a safe YAML scalar" "$err"
  check "Scenario: The tag is not a safe YAML scalar ($badtag: untouched)" "$(<"$dir/before.yml")" "$(<"$dir/vars.yml")"
done

fixture
command rm -f "$dir/vars.yml"
run life_manager_version v0.3.0
check "Scenario: The file is not on main yet (exit)" "1" "$rc"
check "Scenario: The file is not on main yet (stderr)" "bump-pin: $dir/vars.yml: file not found" "$err"

exit "$fail"
