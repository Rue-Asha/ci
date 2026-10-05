#!/usr/bin/env bash
# Fixture tests for scripts/ensure-bump-pr.sh: a local bare repo stands in for
# origin and a stub `gh` stands in for GitHub.

set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 1
script=$PWD/scripts/ensure-bump-pr.sh

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

mkdir "$dir/bin"
cat >"$dir/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >>"$STATE/calls"
case "$1 $2" in
"pr list")
  args=" $* "
  if [[ $args == *" --head "* ]]; then
    [[ $args == *" --head bump/life_manager_version-v0.3.0 "* && $args == *" --state all "* &&
      $args == *" --json number,state,autoMergeRequest"* ]] || { echo "stub: bad head query: $*" >&2; exit 1; }
    cat "$STATE/head.json"
  else
    [[ $args == *" --state open "* && $args == *" --json number,headRefName"* ]] || { echo "stub: bad open query: $*" >&2; exit 1; }
    cat "$STATE/open.json"
  fi ;;
"pr create")
  [ -z "${FAIL_CREATE:-}" ] || { echo "HTTP 502" >&2; exit 1; }
  echo https://github.test/pr/9 ;;
esac
STUB
chmod +x "$dir/bin/gh"

setup() {
  export STATE=$dir/state
  command rm -rf "$dir/origin.git" "$dir/target" "$STATE"
  mkdir "$STATE"
  echo '[]' >"$STATE/head.json"
  echo '[]' >"$STATE/open.json"
  git init -q --bare -b main "$dir/origin.git"
  printf '#!/bin/sh\ncat >>"$STATE/pushes"\n' >"$dir/origin.git/hooks/pre-receive"
  chmod +x "$dir/origin.git/hooks/pre-receive"
  git clone -q "$dir/origin.git" "$dir/target" 2>/dev/null
  (
    cd "$dir/target" || exit 1
    git config user.name t && git config user.email t@t
    echo 'life_manager_version: v0.2.0' >vars.yml
    git add vars.yml && git commit -q -m init && git push -q origin HEAD:main
    git switch -q main 2>/dev/null
  )
  echo 'life_manager_version: v0.3.0' >"$dir/target/vars.yml"
}

run() {
  out=$(cd "$dir/target" && PATH="$dir/bin:$PATH" TARGET_REPO=o/r APP=life-manager VARIABLE=life_manager_version TAG=v0.3.0 bash "$script" "${RESULT:-changed}" 2>"$dir/err")
  rc=$?
  calls=$(cat "$STATE/calls" 2>/dev/null || true)
}
pushes() { grep -c refs/heads/bump/ "$STATE/pushes" 2>/dev/null || true; }
branch_on_origin() { git -C "$dir/origin.git" rev-parse --verify -q refs/heads/bump/life_manager_version-v0.3.0 >/dev/null && echo yes || echo no; }

setup
run
check "Scenario: A new tag is bumped (pushes branch)" "yes" "$(branch_on_origin)"
check "Scenario: A new tag is bumped (opens PR with title)" "1" "$(grep -c '^gh pr create .*--title chore(life-manager): bump to v0.3.0' <<<"$calls")"
check "Scenario: A new tag is bumped (auto-merge)" "1" "$(grep -c '^gh pr merge https://github.test/pr/9 .*--auto --squash' <<<"$calls")"
check "Scenario: A new tag is bumped (pushed commit holds the bumped line)" "life_manager_version: v0.3.0" "$(git -C "$dir/origin.git" show bump/life_manager_version-v0.3.0:vars.yml)"
check "Scenario: A new tag is bumped (commit message)" "chore(life-manager): bump to v0.3.0" "$(git -C "$dir/origin.git" log -1 --format=%s bump/life_manager_version-v0.3.0)"

setup
echo '[{"number":4,"state":"OPEN","autoMergeRequest":{"enabledAt":"x"}}]' >"$STATE/head.json"
git -C "$dir/target" push -q origin HEAD:refs/heads/bump/life_manager_version-v0.3.0
run
check "Scenario: Branch or PR for the tag already exists (open, auto-merge on)" "0" "$(grep -cE '^gh pr (create|merge)' <<<"$calls")"
check "Scenario: Branch or PR for the tag already exists (exit)" "0" "$rc"

setup
echo '[{"number":4,"state":"MERGED","autoMergeRequest":null}]' >"$STATE/head.json"
run
check "Scenario: Branch or PR for the tag already exists (merged)" "0" "$(grep -cE '^gh pr (create|merge)' <<<"$calls")"
check "Scenario: Branch or PR for the tag already exists (merged, no push)" "no" "$(branch_on_origin)"

setup
echo '[{"number":4,"state":"MERGED","autoMergeRequest":null}]' >"$STATE/head.json"
echo '[{"number":3,"headRefName":"bump/life_manager_version-v0.2.9"},{"number":4,"headRefName":"bump/life_manager_version-v0.3.0"}]' >"$STATE/open.json"
run
check "Scenario: An older bump PR is still open (merged current PR: exit)" "0" "$rc"
check "Scenario: An older bump PR is still open (merged current PR: older closed)" "1" "$(grep -c '^gh pr close 3 .*--comment Superseded by 4' <<<"$calls")"
check "Scenario: An older bump PR is still open (merged current PR: only the older)" "1" "$(grep -c '^gh pr close' <<<"$calls")"

setup
FAIL_CREATE=1 run
check "Scenario: A previous run stopped before the PR or auto-merge (create fails: exit)" "1" "$rc"
check "Scenario: A previous run stopped before the PR or auto-merge (create fails: branch pushed)" "yes" "$(branch_on_origin)"
check "Scenario: A previous run stopped before the PR or auto-merge (create fails: one push)" "1" "$(pushes)"
command rm -rf "$dir/target"
git clone -q "$dir/origin.git" "$dir/target" 2>/dev/null
echo 'life_manager_version: v0.3.0' >"$dir/target/vars.yml"
: >"$STATE/calls"
run
check "Scenario: A previous run stopped before the PR or auto-merge (rerun: no second push)" "1" "$(pushes)"
check "Scenario: A previous run stopped before the PR or auto-merge (rerun: exit)" "0" "$rc"
check "Scenario: A previous run stopped before the PR or auto-merge (rerun: PR created, branch not recreated)" "1" "$(grep -c '^gh pr create' <<<"$calls")"
check "Scenario: A previous run stopped before the PR or auto-merge (rerun: auto-merge)" "1" "$(grep -c '^gh pr merge' <<<"$calls")"

setup
echo '[{"number":4,"state":"OPEN","autoMergeRequest":null}]' >"$STATE/head.json"
git -C "$dir/target" push -q origin HEAD:refs/heads/bump/life_manager_version-v0.3.0
run
check "Scenario: A previous run stopped before the PR or auto-merge (PR without auto-merge: no create)" "0" "$(grep -c '^gh pr create' <<<"$calls")"
check "Scenario: A previous run stopped before the PR or auto-merge (PR without auto-merge: enabled)" "1" "$(grep -c '^gh pr merge 4 .*--auto --squash' <<<"$calls")"

setup
echo '[{"number":3,"headRefName":"bump/life_manager_version-v0.2.9"},{"number":9,"headRefName":"bump/life_manager_version-v0.3.0"},{"number":5,"headRefName":"bump/other_version-v1.0.0"},{"number":6,"headRefName":"feat/x"}]' >"$STATE/open.json"
run
check "Scenario: An older bump PR is still open (closes only the older one)" "1" "$(grep -c '^gh pr close' <<<"$calls")"
check "Scenario: An older bump PR is still open (which)" "1" "$(grep -c '^gh pr close 3 .*--comment Superseded by https://github.test/pr/9' <<<"$calls")"

setup
echo '[{"number":8,"headRefName":"bump/life_manager_version-v0.3.1"},{"number":9,"headRefName":"bump/life_manager_version-v0.3.0"},{"number":3,"headRefName":"bump/life_manager_version-v0.2.9"},{"number":2,"headRefName":"bump/life_manager_version-v0.10.0"},{"number":7,"headRefName":"bump/life_manager_version-nightly"},{"number":6,"headRefName":"bump/life_manager_version-v0.3.0-rc1"}]' >"$STATE/open.json"
run
check "Scenario: Only older bump PRs are superseded (exit)" "0" "$rc"
check "Scenario: Only older bump PRs are superseded (closes only the older, numerically)" "1" "$(grep -c '^gh pr close' <<<"$calls")"
check "Scenario: Only older bump PRs are superseded (older closed)" "1" "$(grep -c '^gh pr close 3 ' <<<"$calls")"
check "Scenario: Only older bump PRs are superseded (newer left alone)" "0" "$(grep -cE '^gh pr close (8|2) ' <<<"$calls")"
check "Scenario: Only older bump PRs are superseded (unparseable branch left alone)" "0" "$(grep -cE '^gh pr close (7|6) ' <<<"$calls")"

# The workflow hands the bump-pin.sh result to the script, so the decision is testable here.
setup
echo '[{"number":4,"state":"MERGED","autoMergeRequest":null}]' >"$STATE/head.json"
echo '[{"number":3,"headRefName":"bump/life_manager_version-v0.2.9"},{"number":4,"headRefName":"bump/life_manager_version-v0.3.0"}]' >"$STATE/open.json"
echo 'life_manager_version: v0.3.0' >"$dir/target/vars.yml"
git -C "$dir/target" commit -q -am pinned
RESULT=unchanged run
check "Scenario: The current PR is already merged but an older one is still open (unchanged result: exit)" "0" "$rc"
check "Scenario: The current PR is already merged but an older one is still open (unchanged result: older closed)" "1" "$(grep -c '^gh pr close 3 .*--comment Superseded by 4' <<<"$calls")"
check "Scenario: The current PR is already merged but an older one is still open (unchanged result: no create, merge or push)" "00" "$(grep -cE '^gh pr (create|merge)' <<<"$calls")$(pushes)"

setup
echo '[{"number":3,"headRefName":"bump/life_manager_version-v0.2.9"}]' >"$STATE/open.json"
RESULT=unchanged run
check "Scenario: The value already equals the tag (unchanged result, no PR for the tag: nothing happens)" "00" "$(grep -cE '^gh pr (create|merge|close)' <<<"$calls")$(pushes)"
check "Scenario: The value already equals the tag (unchanged result, no PR for the tag: exit)" "0" "$rc"

setup
for RESULT in skipped "skipped: v0.3.0 is older than the pinned v0.4.0"; do
  : >"$STATE/calls"
  export RESULT
  run
  check "Scenario: A tag older than the pinned version is not bumped (result '$RESULT': no gh call, no push)" "00" "$(grep -c . <<<"$calls" | tr -d '\n')$(pushes)"
done
unset RESULT

check "workflow passes the bump-pin result to ensure-bump-pr.sh unconditionally" "1" "$(grep -c 'ensure-bump-pr.sh "\$result"$' .github/workflows/bump-pin.yml)"

setup
echo '[{"number":8,"headRefName":"bump/life_manager_version-v0.3.18446744073709551617"},{"number":3,"headRefName":"bump/life_manager_version-v0.2.9"}]' >"$STATE/open.json"
run
check "Scenario: Only older bump PRs are superseded (very long number is newer, left alone)" "0" "$(grep -c '^gh pr close 8 ' <<<"$calls")"
check "Scenario: Only older bump PRs are superseded (very long number: older still closed)" "1" "$(grep -c '^gh pr close 3 ' <<<"$calls")"

exit "$fail"
