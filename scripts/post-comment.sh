#!/usr/bin/env bash
set -euo pipefail

# PR Quality Gate — Post PR Comment

if [ -z "${PR_NUMBER:-}" ] || [ -z "${REPO:-}" ]; then
  exit 0
fi

QUALITY_PASS="${QUALITY_PASS:-false}"
REPORT="${REPORT:-{}}"
TOOL_URL="https://creativecodingsolutions.github.io/pr-quality-analyzer"
PR_URL="https://github.com/$REPO/pull/$PR_NUMBER"
ENCODED_PR=$(echo "$PR_URL" | jq -sRr @uri))

build_table() {
  echo "$REPORT" | jq -r '
    to_entries
    | map(select(.key != "summary"))
    | sort_by(.key)
    | map(
        .key as $k |
        (.value.pass // false) as $p |
        (.value.skipped // false) as $s |
        ($k | split("_")[:-1] | join(" ")) as $label |
        if $s then "| " + $label + " | ⏭️ Skipped |"
        elif $p then "| " + $label + " | ✅ Pass |"
        else "| " + $label + " | ❌ Fail |"
        end
      )
    | .[]
  '
}

if [ "$QUALITY_PASS" = "true" ]; then
  TABLE=$(build_table)
  BODY="## ✅ PR Quality Gate — All Checks Passed

| Check | Status |
|-------|--------|
$TABLE

---

**📊 [Score this PR on PR Quality Analyzer](https://creativecodingsolutions.github.io/pr-quality-analyzer/?pr=$ENCODED_PR)** — Get an A-F score with detailed metrics.

*Powered by [PR Quality Gate](https://github.com/CreativeCodingSolutions/pr-quality-gate)*
"
else
  ISSUES=$(echo "$REPORT" | jq -r '
    to_entries
    | map(select(.value.pass == false))
    | map("  - ❌ **\(.key | split("_")[:-1] | join(" "))** — \(.value.message)")
    | join("\\n")
  ')
  TABLE=$(build_table)

  BODY="## ❌ PR Quality Gate — Issues Found

| Check | Status |
|-------|--------|
$TABLE

$ISSUES

---

Please fix these issues to pass the quality gate.

Need help writing PR descriptions? Try to:
- Explain **what** this change does
- Explain **why** this change is needed
- Link to any related issues or discussions

**📊 [Score this PR on PR Quality Analyzer](https://creativecodingsolutions.github.io/pr-quality-analyzer/?pr=$ENCODED_PR)** — Get an A-F score with detailed metrics.

*Powered by [PR Quality Gate](https://github.com/CreativeCodingSolutions/pr-quality-gate)*
"

  if [ -n "${CUSTOM_MESSAGE:-}" ]; then
    BODY="$BODY"$'\n\n---\n**Custom note:** '"$CUSTOM_MESSAGE"
  fi
fi

gh api "/repos/$REPO/issues/$PR_NUMBER/comments" \
  --field body="$BODY" \
  --silent 2>/dev/null || true
