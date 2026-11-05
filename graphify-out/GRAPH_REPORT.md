# Graph Report - ci  (2026-11-05)

## Corpus Check
- Corpus is ~4,825 words - fits in a single context window. You may not need a graph.

## Summary
- 170 nodes · 183 edges · 16 communities (15 shown, 1 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 5 edges (avg confidence: 0.83)
- Token cost: 46,786 input · 0 output

## Community Hubs (Navigation)
- Shared Workflows Overview
- Bump-Pin Workflow Inputs
- Bump-Pin Job Steps
- Security Baseline Jobs
- App Token & Checkout Config
- Security Baseline Steps
- Self-Check Workflow
- Bump PR Lifecycle
- Workflow Lint Tooling
- Dependabot Config
- Bump-Pin Workflow Root
- Bump-Pin Secrets
- Actionlint Config
- Pin Edit Script
- Ensure Bump PR Script
- Version Comparison

## God Nodes (most connected - your core abstractions)
1. `with` - 12 edges
2. `bump-pin reusable workflow` - 9 edges
3. `steps` - 8 edges
4. `env` - 7 edges
5. `inputs` - 6 edges
6. `steps` - 6 edges
7. `with` - 6 edges
8. `security-baseline reusable workflow` - 6 edges
9. `bump` - 5 edges
10. `workflow-lint` - 5 edges

## Surprising Connections (you probably didn't know these)
- `Upward-only pin with semver validation` --rationale_for--> `scripts/bump-pin.sh (pin edit)`  [INFERRED]
  README.md → README.md  _Bridges community 0 → community 7_

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **security-baseline required checks** — readme_workflow_lint_job, readme_secret_scan_job, readme_dependency_review_job, readme_job_names_as_interface [EXTRACTED 1.00]
- **bump-pin release-to-PR flow** — readme_bump_pin_workflow, readme_bump_pin_script, readme_ensure_bump_pr_script, readme_squash_auto_merge, readme_superseded_pr_cleanup, readme_github_app_token [EXTRACTED 1.00]
- **bump-pin safety guarantees** — readme_upward_only_pin, readme_bump_concurrency_group, readme_idempotent_rerun [INFERRED 0.85]

## Communities (16 total, 1 thin omitted)

### Community 0 - "Shared Workflows Overview"
Cohesion: 0.12
Nodes (18): actionlint, concurrency group bump-<variable>, bump-pin inputs (app, host_vars_path, variable, tag, target_repo), scripts/bump-pin.sh (pin edit), bump-pin reusable workflow, ci: Shared GitHub Actions Workflows, Dependabot, dependency-review job (+10 more)

### Community 1 - "Bump-Pin Workflow Inputs"
Cohesion: 0.09
Nodes (22): description, required, type, description, required, type, app, host_vars_path (+14 more)

### Community 2 - "Bump-Pin Job Steps"
Cohesion: 0.11
Nodes (19): concurrency, name, runs-on, steps, cancel-in-progress, group, APP, FILE (+11 more)

### Community 3 - "Security Baseline Jobs"
Cohesion: 0.12
Nodes (16): if, name, runs-on, GITLEAKS_SHA256, GITLEAKS_VERSION, jobs, dependency-review, secret-scan (+8 more)

### Community 4 - "App Token & Checkout Config"
Cohesion: 0.17
Nodes (12): with, app-id, owner, path, permission-contents, permission-pull-requests, persist-credentials, private-key (+4 more)

### Community 5 - "Security Baseline Steps"
Cohesion: 0.24
Nodes (12): steps, GH_TOKEN, steps, env, name, run, uses, with (+4 more)

### Community 6 - "Self-Check Workflow"
Cohesion: 0.17
Nodes (11): jobs, security-baseline, name, on, pull_request, push, permissions, contents (+3 more)

### Community 7 - "Bump PR Lifecycle"
Cohesion: 0.23
Nodes (8): scripts/ensure-bump-pr.sh (branch, PR, auto-merge), Squash auto-merge on bump PR, Closing older bump/<variable>-* PRs, check(), pushes(), run(), setup(), ensure-bump-pr.sh script

### Community 8 - "Workflow Lint Tooling"
Cohesion: 0.25
Nodes (8): ACTIONLINT_SHA256, ACTIONLINT_VERSION, ZIZMOR_SHA256, ZIZMOR_VERSION, workflow-lint, env, name, runs-on

### Community 9 - "Dependabot Config"
Cohesion: 0.29
Nodes (6): interval, updates, directory, package-ecosystem, schedule, version

### Community 10 - "Bump-Pin Workflow Root"
Cohesion: 0.33
Nodes (5): jobs, name, on, permissions, contents

### Community 11 - "Bump-Pin Secrets"
Cohesion: 0.40
Nodes (5): required, required, app_id, app_private_key, secrets

### Community 12 - "Actionlint Config"
Cohesion: 0.50
Nodes (3): ignore, paths, .github/workflows/bump-pin.yml

### Community 13 - "Pin Edit Script"
Cohesion: 0.50
Nodes (3): BUMP_TAG, BUMP_VAR, bump-pin.sh script

### Community 14 - "Ensure Bump PR Script"
Cohesion: 0.83
Nodes (3): older_than_current(), ensure-bump-pr.sh script, supersede()

## Knowledge Gaps
- **9 isolated node(s):** `BUMP_VAR`, `BUMP_TAG`, `dependency-review job`, `actionlint`, `zizmor` (+4 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 90 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `steps` connect `Bump-Pin Job Steps` to `App Token & Checkout Config`?**
  _High betweenness centrality (0.079) - this node is a cross-community bridge._
- **What connects `BUMP_VAR`, `BUMP_TAG`, `dependency-review job` to the rest of the system?**
  _9 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Shared Workflows Overview` be split into smaller, more focused modules?**
  _Cohesion score 0.11857707509881422 - nodes in this community are weakly interconnected._
- **Why does `bump` connect `Bump-Pin Job Steps` to `Bump-Pin Workflow Root`?**
  _High betweenness centrality (0.079) - this node is a cross-community bridge._
- **Should `Bump-Pin Workflow Inputs` be split into smaller, more focused modules?**
  _Cohesion score 0.09090909090909091 - nodes in this community are weakly interconnected._
- **Why does `workflow_call` connect `Bump-Pin Workflow Inputs` to `Bump-Pin Workflow Root`, `Bump-Pin Secrets`?**
  _High betweenness centrality (0.075) - this node is a cross-community bridge._
- **Should `Bump-Pin Job Steps` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._