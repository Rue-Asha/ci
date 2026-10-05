#!/usr/bin/env bash
# Usage: ensure-bump-pr.sh   (in the target checkout, with the bumped file unstaged)
# Env: TARGET_REPO APP VARIABLE TAG, and GH_TOKEN for gh.
# Brings branch bump/<variable>-<tag>, its PR and the PR's auto-merge to the
# state a finished run leaves, doing only the steps that are still missing, so
# a re-run after a partial failure completes it.

set -euo pipefail

branch="bump/${VARIABLE}-${TAG}"
title="chore(${APP}): bump to ${TAG}"

pr=$(gh pr list --repo "$TARGET_REPO" --head "$branch" --state all --json number,state,autoMergeRequest |
  jq -r '.[0] // empty | "\(.number) \(.state) \(.autoMergeRequest != null)"')
read -r number state automerge <<<"$pr"

if [ "${state:-}" = MERGED ] || [ "${state:-}" = CLOSED ]; then
  echo "bump-pin: PR $number for $branch is ${state,,}, nothing to do"
  exit 0
fi

if [ -z "${number:-}" ]; then
  if git ls-remote --exit-code --heads origin "$branch" >/dev/null; then
    echo "bump-pin: $branch exists without a PR, opening it"
  else
    git config user.name "homelab-bump[bot]"
    git config user.email "homelab-bump[bot]@users.noreply.github.com"
    git switch -c "$branch"
    git commit -am "$title"
    git push origin "$branch"
  fi
  number=$(gh pr create --repo "$TARGET_REPO" --head "$branch" --title "$title" \
    --body "Automated bump of \`${VARIABLE}\` to \`${TAG}\`, opened by the release of ${APP}.")
  automerge=false
fi

if [ "$automerge" != true ]; then
  gh pr merge "$number" --repo "$TARGET_REPO" --auto --squash
else
  echo "bump-pin: PR $number for $branch already set to auto-merge"
fi

gh pr list --repo "$TARGET_REPO" --state open --json number,headRefName |
  jq -r --arg prefix "bump/${VARIABLE}-" --arg branch "$branch" \
    '.[] | select((.headRefName | startswith($prefix)) and .headRefName != $branch) | .number' |
  while read -r old; do
    gh pr close "$old" --repo "$TARGET_REPO" --comment "Superseded by ${number}"
  done
