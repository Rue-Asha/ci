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
