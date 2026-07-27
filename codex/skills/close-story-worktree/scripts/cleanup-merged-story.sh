#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: cleanup-merged-story.sh <story-id> <branch> [--worktree <absolute-path>] [--apply]" >&2
  exit 2
}

ID=${1:-}
BRANCH=${2:-}
[ -n "$ID" ] && [ -n "$BRANCH" ] || usage
shift 2

WORKTREE=""
APPLY=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --worktree)
      [ "$#" -ge 2 ] || usage
      WORKTREE=$2
      shift 2
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    *)
      usage
      ;;
  esac
done

[[ "$ID" =~ ^[A-Za-z][A-Za-z0-9_-]*-[0-9]+$ ]] || {
  echo "invalid story ID: $ID" >&2
  exit 2
}
git check-ref-format --branch "$BRANCH" >/dev/null
command -v gh >/dev/null 2>&1 || {
  echo "gh is required" >&2
  exit 2
}
gh auth status >/dev/null

ROOT=$(git rev-parse --show-toplevel)
ROOT=$(cd "$ROOT" && pwd -P)

PR_HEAD=$(gh pr view "$BRANCH" --json headRefName --jq '.headRefName')
PR_BASE=$(gh pr view "$BRANCH" --json baseRefName --jq '.baseRefName')
PR_URL=$(gh pr view "$BRANCH" --json url --jq '.url')
MERGED_AT=$(gh pr view "$BRANCH" --json mergedAt --jq '.mergedAt // ""')

[ "$PR_HEAD" = "$BRANCH" ] || {
  echo "PR head mismatch: expected $BRANCH, found $PR_HEAD" >&2
  exit 1
}
[ -n "$MERGED_AT" ] || {
  echo "PR is not merged: $PR_URL" >&2
  exit 1
}

if [ -z "$WORKTREE" ]; then
  WORKTREE=$(git worktree list --porcelain | awk -v ref="refs/heads/$BRANCH" '
    $1 == "worktree" { path = substr($0, 10) }
    $1 == "branch" && $2 == ref { print path; exit }
  ')
fi

[ -n "$WORKTREE" ] || {
  echo "no worktree found for branch: $BRANCH" >&2
  exit 1
}
case "$WORKTREE" in
  /*) ;;
  *)
    echo "worktree path must be absolute: $WORKTREE" >&2
    exit 2
    ;;
esac

WORKTREE=$(cd "$WORKTREE" && pwd -P)
[ "$WORKTREE" != "$ROOT" ] || {
  echo "refusing to remove the primary worktree: $ROOT" >&2
  exit 1
}
[ "$(git -C "$WORKTREE" rev-parse --show-toplevel)" = "$WORKTREE" ] || {
  echo "resolved path is not the worktree root: $WORKTREE" >&2
  exit 1
}
[ "$(git -C "$WORKTREE" branch --show-current)" = "$BRANCH" ] || {
  echo "worktree branch mismatch at $WORKTREE" >&2
  exit 1
}
[ -z "$(git -C "$WORKTREE" status --porcelain)" ] || {
  echo "worktree is dirty; refusing cleanup: $WORKTREE" >&2
  git -C "$WORKTREE" status --short >&2
  exit 1
}

echo "story: $ID"
echo "pr: $PR_URL"
echo "merged: $MERGED_AT"
echo "base: $PR_BASE"
echo "branch: $BRANCH"
echo "worktree: $WORKTREE"

if [ "$APPLY" -eq 0 ]; then
  echo "preview only; rerun with --apply to remove the worktree and local branch"
  exit 0
fi

git fetch origin "$PR_BASE"
git merge-base --is-ancestor "$BRANCH" "origin/$PR_BASE" || {
  echo "branch tip is not an ancestor of origin/$PR_BASE; refusing cleanup" >&2
  echo "the PR may have been squash-merged; ask for a separate recoverability decision" >&2
  exit 1
}

git worktree remove -- "$WORKTREE"
git branch -d -- "$BRANCH"

echo "local cleanup complete"
