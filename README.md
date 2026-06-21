# PR Quality Gate

[![GitHub Stars](https://img.shields.io/github/stars/CreativeCodingSolutions/pr-quality-gate?style=flat-square)](https://github.com/CreativeCodingSolutions/pr-quality-gate)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![GitHub Actions](https://img.shields.io/badge/GitHub-Actions-2088FF?style=flat-square&logo=github-actions)](https://github.com/CreativeCodingSolutions/pr-quality-gate/actions)

Enforce PR quality standards: description length, labels, and linked issues. Zero config, one-minute setup.

Works alongside [DocuCraft](https://github.com/CreativeCodingSolutions/docucraft) — DocuCraft generates great descriptions, PR Quality Gate ensures they stay that way.

## Usage

Add this to `.github/workflows/pr-quality.yml`:

```yaml
name: PR Quality Gate
on: pull_request
permissions: { contents: read, pull-requests: write, issues: read }
jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: CreativeCodingSolutions/pr-quality-gate@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          min-description-length: "50"
          require-labels: "true"
          require-linked-issue: "false"
```

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `github-token` | `${{ github.token }}` | GitHub token for API access |
| `min-description-length` | `50` | Minimum characters for PR description |
| `require-labels` | `false` | Require PR to have at least one label |
| `require-linked-issue` | `false` | Require PR to link to an issue |
| `fail-on-warning` | `true` | Fail CI if quality standards not met |
| `mode` | `fail` | `fail` or `warn` — fail the check or just warn |
| `comment-on-pr` | `true` | Post a quality report comment on the PR |
| `custom-message` | `""` | Custom message to include in PR comment |

## Outputs

| Output | Description |
|--------|-------------|
| `quality-pass` | `true`/`false` — whether all checks passed |
| `description-length` | Length of PR description in characters |
| `has-labels` | `true`/`false` |
| `has-linked-issue` | `true`/`false` |
| `report` | Full quality report as JSON |

## Examples

### Warn-only mode (don't block CI)

```yaml
- uses: CreativeCodingSolutions/pr-quality-gate@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    mode: warn
    comment-on-pr: true
```

### Require everything

```yaml
- uses: CreativeCodingSolutions/pr-quality-gate@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    min-description-length: "150"
    require-labels: "true"
    require-linked-issue: "true"
    fail-on-warning: "true"
```

### With custom message

```yaml
- uses: CreativeCodingSolutions/pr-quality-gate@v1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    min-description-length: "100"
    mode: warn
    custom-message: "Please follow our PR guidelines: https://github.com/org/contributing#prs"
```

## Why PR Quality Gate?

Our [analysis of 1,500+ PRs across 175 open-source repos](https://github.com/CreativeCodingSolutions/docucraft) found that **13% of repos have a chronic PR description problem** and **5% of all PRs have zero description**.

PR Quality Gate catches these issues before they land:

- **Short descriptions** — Flags PRs where the body is too short to be useful
- **Missing labels** — Ensures PRs are categorized for release notes and filtering
- **Unlinked issues** — Encourages traceability between changes and discussions

Pro tip: Pair with [DocuCraft](https://github.com/CreativeCodingSolutions/docucraft) to auto-generate structured PR descriptions from diffs.
