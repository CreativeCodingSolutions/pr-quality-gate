#!/usr/bin/env bash
set -euo pipefail

# PR Quality Gate — Post PR Comment

if [ -z "${PR_NUMBER:-}" ] || [ -z "${REPO:-}" ]; then
  exit 0
fi

QUALITY_PASS="${QUALITY_PASS:-false}"
REPORT="${REPORT:-{}}"

if [ "$QUALITY_PASS" = "true" ]; then
  BODY="## ✅ PR Quality Gate — All Checks Passed

| Check | Status |
|-------|--------|

$(echo "$REPORT" | jq -r '
  ["description_check", "labels_check", "linked_issue_check"] 
  | map(select(.[0] as $key | .[1] | has("skipped") | not))
  | map("<tr><td>\(.[0] | split("_") | map(ascii_upcase[:1] + .[1:]) | join(" "))</td><td>✅ Pass</td></tr>")
  | join("\\n")
')

---

*Powered by [PR Quality Gate](https://github.com/CreativeCodingSolutions/pr-quality-gate)*
"
else
  ISSUES=$(echo "$REPORT" | jq -r '
    to_entries 
    | map(select(.value.pass == false))
    | map("  - ❌ **\(.key | split("_")[0:] | join(" "))** — \(.value.message)")
    | join("\\n")
  ')

  BODY="## ❌ PR Quality Gate — Issues Found

$ISSUES

---

Please fix these issues to pass the quality gate. 

Need help writing PR descriptions? Try to:
- Explain **what** this change does
- Explain **why** this change is needed
- Link to any related issues or discussions

*Powered by [PR Quality Gate](https://github.com/CreativeCodingSolutions/pr-quality-gate)*
"

  if [ -n "${CUSTOM_MESSAGE:-}" ]; then
    BODY="$BODY"$'\n\n---\n**Custom note:** '"$CUSTOM_MESSAGE"
  fi
fi

gh api "/repos/$REPO/issues/$PR_NUMBER/comments" \
  --field body="$BODY" \
  --silent 2>/dev/null || true
