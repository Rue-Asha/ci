# ci

Shared GitHub Actions workflows for Rue-Asha repos.

## security-baseline

`.github/workflows/security-baseline.yml` is a reusable workflow with three
jobs:

| Job | What it checks |
|---|---|
| `workflow-lint` | actionlint and zizmor over `.github/workflows/`; every `uses:` must be pinned to a commit SHA |
| `secret-scan` | gitleaks over the full git history |
| `dependency-review` | on pull requests only: fails on a new dependency with a high or critical advisory |

Call it pinned to a full commit SHA, with the release in a comment so
Dependabot keeps both current:

```yaml
permissions:
  contents: read

jobs:
  security-baseline:
    uses: Rue-Asha/ci/.github/workflows/security-baseline.yml@<sha> # v1.0.0
```

A ruleset requires the jobs as `security-baseline / workflow-lint`,
`security-baseline / secret-scan` and `security-baseline / dependency-review`.
Job names are part of the interface; renaming one is a major version.

The scanner binaries are pinned by version and SHA-256 inside the workflow.
Dependabot does not bump those; update version and checksum together.

## bump-pin

`.github/workflows/bump-pin.yml` is a reusable workflow that sets a pinned
version variable in a target repo (default `Rue-Asha/Homelab-Managment`) to a
release tag, pushes `bump/<variable>-<tag>`, opens a PR titled
`chore(<app>): bump to <tag>`, enables squash auto-merge on it and closes older
open `bump/<variable>-*` PRs. The edit is made by `scripts/bump-pin.sh`, tested
by `tests/bump-pin.sh`; the branch, PR and auto-merge steps are in
`scripts/ensure-bump-pr.sh`, tested by `tests/ensure-bump-pr.sh`. A pre-release
tag (`v1.2.3-rc1`), a value that already equals the tag, and a PR for the tag
that is merged or already set to auto-merge end green without changes. A run
that stopped half-way is completed by a re-run (missing PR or auto-merge is
added); a missing file or variable line fails the job.

| Input | |
|---|---|
| `app` | name for the PR title, e.g. `life-manager` |
| `host_vars_path` | file to edit, relative to the target repo root |
| `variable` | variable to set, e.g. `life_manager_version` |
| `tag` | release tag, e.g. `v0.3.0` |
| `target_repo` | optional, default `Rue-Asha/Homelab-Managment` |

Secrets `app_id` and `app_private_key` are those of a GitHub App installed on
the target repo (Contents and Pull requests read/write). The PR is opened with
its token so the target's CI runs on it; there is no fallback to
`GITHUB_TOKEN`. Pass them explicitly, not with `secrets: inherit`.

```yaml
bump:
  needs: publish
  permissions:
    contents: read
  uses: Rue-Asha/ci/.github/workflows/bump-pin.yml@<sha> # v1.1.0
  with:
    app: life-manager
    host_vars_path: ansible/inventory/host_vars/life-manager01/vars.yml
    variable: life_manager_version
    tag: ${{ github.ref_name }}
  secrets:
    app_id: ${{ secrets.HOMELAB_BUMP_APP_ID }}
    app_private_key: ${{ secrets.HOMELAB_BUMP_APP_KEY }}
```

The job name `bump` is part of the interface; renaming it is a major version.
