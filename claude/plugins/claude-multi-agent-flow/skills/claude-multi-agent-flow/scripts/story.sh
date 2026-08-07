#!/usr/bin/env bash
set -euo pipefail

ID=${1:?usage: story.sh <STORY-ID> [base-branch]}
BASE=${2:-${BASE_BRANCH:-}}

if [[ ! "$ID" =~ ^[A-Za-z][A-Za-z0-9_-]*-[0-9]+$ ]]; then
  echo "invalid story ID: $ID" >&2
  exit 2
fi

for command_name in claude codex git tee jq grep mkdir; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "missing command: $command_name" >&2
    exit 2
  }
done

ROOT=$(git rev-parse --show-toplevel)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BRANCH="worktree-$ID"
WT="${WORKTREE_PATH:-$ROOT/.claude/worktrees/$ID}"
SPEC="$WT/specs/$ID.md"
NOTES="$WT/.claude-flow/$ID"

if [ -z "$BASE" ]; then
  REMOTE_HEAD=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  BASE=${REMOTE_HEAD#origin/}
fi
if [ -z "$BASE" ]; then
  BASE=$(git branch --show-current)
fi
if [ -z "$BASE" ] || ! git check-ref-format --branch "$BASE" >/dev/null 2>&1; then
  echo "unable to determine a valid base branch; pass it explicitly" >&2
  exit 2
fi

if [ ! -d "$WT" ]; then
  echo "missing worktree: $WT" >&2
  echo "run new-story.sh $ID $BASE first" >&2
  exit 1
fi
if [ "$(git -C "$WT" branch --show-current)" != "$BRANCH" ]; then
  echo "unexpected worktree branch at $WT" >&2
  exit 1
fi

REVIEW_BASE="$BASE"
if git -C "$WT" rev-parse --verify "origin/$BASE^{commit}" >/dev/null 2>&1; then
  REVIEW_BASE="origin/$BASE"
fi
mkdir -p "$NOTES"

if [ -n "${SOT_QUERY:-}" ]; then
  BUILD_PROMPT="Use this source-of-truth query exactly once and fetch only the fields needed for story $ID: $SOT_QUERY. Write specs/$ID.md with machine-readable Done-when commands, then implement it per CLAUDE.md. Commit the spec, implementation, tests, and intended artifacts when checks pass. Do not push, open a PR, merge, rebase, or edit outside this worktree."
else
  if [ ! -f "$SPEC" ]; then
    echo "missing local spec: $SPEC" >&2
    exit 1
  fi
  if grep -Eq '<[^>]+>' "$SPEC"; then
    echo "local spec still contains placeholders: $SPEC" >&2
    echo "complete it or set SOT_QUERY before running story.sh" >&2
    exit 1
  fi
  BUILD_PROMPT="Read specs/$ID.md as the local execution contract. Do not fetch an external source of truth. Implement it per CLAUDE.md. Commit the spec, implementation, tests, and intended artifacts when checks pass. Do not push, open a PR, merge, rebase, or edit outside this worktree."
fi

run_claude() {
  local stage=$1
  local prompt=$2
  local max_turns=$3
  (
    cd "$WT"
    claude -p "$prompt" --output-format stream-json --verbose --max-turns "$max_turns"
  ) \
    | tee -a "$NOTES/$stage-trace.jsonl" \
    | jq -r 'if .type=="system" then "> start: \(.model // "")"
             elif .type=="assistant" then (.message.content[]? | select(.type=="tool_use")
                  | "  * \(.name): \(.input.file_path // .input.command // "")")
             elif .type=="result" then "= done $\(.total_cost_usd // 0) / \(.num_turns // 0) turns"
             else empty end'
}

run_review() {
  local stage=$1
  local prompt=$2
  codex exec \
    -C "$WT" \
    -s read-only \
    -c 'approval_policy="never"' \
    --json \
    -o "$NOTES/$stage.md" \
    "$prompt" \
    | tee "$NOTES/$stage-trace.jsonl"
}

read_review_verdict() {
  local file=$1
  local verdict=""
  if [ ! -f "$file" ]; then
    echo "reviewer did not produce a verdict file: $file" >&2
    return 1
  fi
  if ! IFS= read -r verdict < "$file" && [ -z "$verdict" ]; then
    echo "reviewer did not produce a verdict in: $file" >&2
    return 1
  fi
  case "$verdict" in
    "VERDICT: PASS"|"VERDICT: CHANGES_REQUESTED")
      printf '%s\n' "$verdict"
      ;;
    *)
      echo "invalid reviewer verdict in $file: $verdict" >&2
      return 1
      ;;
  esac
}

require_clean_commit() {
  local stage=$1
  if [ -n "$(git -C "$WT" status --porcelain)" ]; then
    echo "$stage left uncommitted or untracked files in the story worktree" >&2
    git -C "$WT" status --short >&2
    exit 1
  fi
  if git -C "$WT" diff --quiet "$REVIEW_BASE"...HEAD; then
    echo "$stage produced no committed branch changes against $REVIEW_BASE" >&2
    exit 1
  fi
}

echo "1/5 build"
BEFORE_BUILD=$(git -C "$WT" rev-parse HEAD)
run_claude build "$BUILD_PROMPT" 40
require_clean_commit "builder"
if [ "$(git -C "$WT" rev-parse HEAD)" = "$BEFORE_BUILD" ]; then
  echo "builder produced no new commit" >&2
  exit 1
fi

echo "2/5 verify before review"
"$SCRIPT_DIR/verify.sh" "$WT" | tee "$NOTES/$ID-verify-before-review.log"

echo "3/5 independent review"
run_review review \
  "Act as the independent reviewer. Review git diff $REVIEW_BASE...HEAD against specs/$ID.md and applicable AGENTS.md or CLAUDE.md. Inspect related code and tests only as needed to validate findings. Do not edit files. First line must be exactly VERDICT: PASS or VERDICT: CHANGES_REQUESTED. For each finding include P0, P1, or P2 severity, file and line, a reachable failure scenario, and the smallest safe correction. Exclude style-only or speculative findings."

FIX_RAN=0
REVIEW_VERDICT=$(read_review_verdict "$NOTES/review.md")
if [ "$REVIEW_VERDICT" = "VERDICT: PASS" ]; then
  echo "4/5 fix skipped because review passed"
else
  FIX_RAN=1
  BEFORE_FIX=$(git -C "$WT" rev-parse HEAD)
  echo "4/5 one bounded fix pass"
  run_claude fix \
    "Read .claude-flow/$ID/review.md and specs/$ID.md. Validate every review finding against the code. Address only valid in-scope findings, add regression tests where practical, and explain any rejected finding. Commit accepted corrections. Stop and report instead of guessing when a design decision is required. Do not push, open a PR, merge, rebase, or edit outside this worktree." \
    20
  require_clean_commit "fix pass"
  if [ "$(git -C "$WT" rev-parse HEAD)" = "$BEFORE_FIX" ]; then
    echo "fix pass requested changes but produced no new commit" >&2
    exit 1
  fi
fi

echo "5/5 final verify"
"$SCRIPT_DIR/verify.sh" "$WT" | tee "$NOTES/$ID-verify-final.log"

if [ "$FIX_RAN" = "1" ]; then
  echo "final re-review after fix"
  run_review rereview \
    "Act as the independent reviewer after one bounded fix pass. Review git diff $REVIEW_BASE...HEAD, specs/$ID.md, and .claude-flow/$ID/review.md. Do not edit files. First line must be exactly VERDICT: PASS or VERDICT: CHANGES_REQUESTED. Report only remaining P0, P1, or P2 findings with file, line, failure scenario, and smallest safe correction."
  REREVIEW_VERDICT=$(read_review_verdict "$NOTES/rereview.md")
  if [ "$REREVIEW_VERDICT" != "VERDICT: PASS" ]; then
    echo "re-review still requests changes; stop for human decision" >&2
    exit 1
  fi
fi

echo "ready for human PR gate"
echo "story: $ID"
echo "branch: $BRANCH"
echo "base: $BASE"
echo "worktree: $WT"
echo "flow records: $NOTES"
echo "suggested command: gh pr create --base $BASE --head $BRANCH --fill"
