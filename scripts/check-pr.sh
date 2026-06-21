#!/usr/bin/env bash
set -euo pipefail

# PR Quality Gate — PR Quality Check
# Inspects PR description, labels, and linked issues.

if [ -z "${PR_NUMBER:-}" ]; then
  echo "quality-pass=false" >> $GITHUB_OUTPUT
  echo "description-length=0" >> $GITHUB_OUTPUT
  echo "has-labels=false" >> $GITHUB_OUTPUT
  echo "has-linked-issue=false" >> $GITHUB_OUTPUT
  echo "report={\"error\":\"No PR number available\"}" >> $GITHUB_OUTPUT
  exit 0
fi

RESULTS="{}"
ALL_PASS=true
ISSUES=()

# Check description length
if PR_DATA=$(gh api "/repos/$REPO/pulls/$PR_NUMBER" --jq '{body: .body, title: .title}' 2>/dev/null); then
  BODY=$(echo "$PR_DATA" | jq -r '.body // ""')
  TITLE=$(echo "$PR_DATA" | jq -r '.title // ""')
  DESC_LENGTH=${#BODY}

  echo "description-length=$DESC_LENGTH" >> $GITHUB_OUTPUT

  if [ "$DESC_LENGTH" -lt "$MIN_DESC_LENGTH" ] 2>/dev/null; then
    ALL_PASS=false
    ISSUES+=("Description too short (${DESC_LENGTH} chars, minimum ${MIN_DESC_LENGTH})")
    RESULTS=$(echo "$RESULTS" | jq --arg msg "Description is only ${DESC_LENGTH} characters (minimum ${MIN_DESC_LENGTH})" '. + {"description_check": {"pass": false, "message": $msg}}')
  else
    RESULTS=$(echo "$RESULTS" | jq '. + {"description_check": {"pass": true, "length": '"$DESC_LENGTH"'}}')
  fi
else
  DESC_LENGTH=0
  echo "description-length=0" >> $GITHUB_OUTPUT
  RESULTS=$(echo "$RESULTS" | jq '. + {"description_check": {"pass": false, "message": "Could not fetch PR data"}}')
fi

# Check labels
if [ "${REQUIRE_LABELS:-false}" = "true" ]; then
  if LABELS=$(gh api "/repos/$REPO/issues/$PR_NUMBER/labels" --jq 'length' 2>/dev/null); then
    if [ "$LABELS" -gt 0 ]; then
      echo "has-labels=true" >> $GITHUB_OUTPUT
      RESULTS=$(echo "$RESULTS" | jq --argjson count "$LABELS" '. + {"labels_check": {"pass": true, "count": $count}}')
    else
      echo "has-labels=false" >> $GITHUB_OUTPUT
      ALL_PASS=false
      ISSUES+=("PR has no labels")
      RESULTS=$(echo "$RESULTS" | jq '. + {"labels_check": {"pass": false, "message": "PR has no labels"}}')
    fi
  else
    echo "has-labels=false" >> $GITHUB_OUTPUT
    RESULTS=$(echo "$RESULTS" | jq '. + {"labels_check": {"pass": false, "message": "Could not check labels"}}')
  fi
else
  echo "has-labels=false" >> $GITHUB_OUTPUT
  RESULTS=$(echo "$RESULTS" | jq '. + {"labels_check": {"pass": true, "skipped": true}}')
fi

# Check linked issues
if [ "${REQUIRE_LINKED_ISSUE:-false}" = "true" ]; then
  if LINKED=$(gh api "/repos/$REPO/issues/$PR_NUMBER/timeline" --jq '[.[] | select(.source.issue != null or .body | test("(close|fix|resolve)s? #[0-9]+"; "i"))] | length' 2>/dev/null); then
    if [ "$LINKED" -gt 0 ]; then
      echo "has-linked-issue=true" >> $GITHUB_OUTPUT
      RESULTS=$(echo "$RESULTS" | jq --argjson count "$LINKED" '. + {"linked_issue_check": {"pass": true, "count": $count}}')
    else
      echo "has-linked-issue=false" >> $GITHUB_OUTPUT
      ALL_PASS=false
      ISSUES+=("PR has no linked issue")
      RESULTS=$(echo "$RESULTS" | jq '. + {"linked_issue_check": {"pass": false, "message": "PR has no linked issue"}}')
    fi
  else
    echo "has-linked-issue=false" >> $GITHUB_OUTPUT
    RESULTS=$(echo "$RESULTS" | jq '. + {"linked_issue_check": {"pass": false, "message": "Could not check linked issues"}}')
  fi
else
  echo "has-linked-issue=false" >> $GITHUB_OUTPUT
  RESULTS=$(echo "$RESULTS" | jq '. + {"linked_issue_check": {"pass": true, "skipped": true}}')
fi

# Build final report
if [ "$ALL_PASS" = true ]; then
  echo "quality-pass=true" >> $GITHUB_OUTPUT
  RESULTS=$(echo "$RESULTS" | jq '. + {"summary": {"pass": true, "message": "All quality checks passed"}}')
else
  echo "quality-pass=false" >> $GITHUB_OUTPUT
  JOINED=$(printf "\\n- %s" "${ISSUES[@]}")
  RESULTS=$(echo "$RESULTS" | jq --arg msg "Quality issues found:$JOINED" '. + {"summary": {"pass": false, "message": $msg}}')
fi

echo "report=$(echo "$RESULTS" | jq -c .)" >> $GITHUB_OUTPUT

# Fail if mode is fail and checks didn't pass
if [ "$ALL_PASS" = false ] && [ "${MODE:-fail}" = "fail" ]; then
  echo "PR Quality Gate: Some checks failed. See the PR comment for details."
  exit 1
fi
