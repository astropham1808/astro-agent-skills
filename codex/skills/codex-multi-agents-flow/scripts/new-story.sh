#!/usr/bin/env bash
set -euo pipefail

ID=${1:?usage: new-story.sh <STORY-ID> [base-branch]}
BASE=${2:-${BASE_BRANCH:-main}}

if [[ ! "$ID" =~ ^[A-Za-z][A-Za-z0-9_-]*-[0-9]+$ ]]; then
  echo "invalid story ID: $ID" >&2
  exit 2
fi

for command_name in git mkdir cp grep sed rm; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "missing command: $command_name" >&2
    exit 2
  }
done

if ! git check-ref-format --branch "$BASE" >/dev/null 2>&1; then
  echo "invalid base branch: $BASE" >&2
  exit 2
fi

ROOT=$(git rev-parse --show-toplevel)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BRANCH="codex/$ID"
WT="${WORKTREE_PATH:-$ROOT/.agent-worktrees/$ID}"

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "branch already exists: $BRANCH" >&2
  exit 1
fi

if [ -e "$WT" ]; then
  echo "worktree path already exists: $WT" >&2
  exit 1
fi

BASE_REF="$BASE"
if git remote get-url origin >/dev/null 2>&1; then
  if [ "${FETCH_BASE:-1}" = "1" ]; then
    git fetch --prune origin "$BASE"
  fi
  if git show-ref --verify --quiet "refs/remotes/origin/$BASE"; then
    BASE_REF="origin/$BASE"
  fi
fi

if ! git rev-parse --verify "$BASE_REF^{commit}" >/dev/null 2>&1; then
  echo "base branch not found: $BASE_REF" >&2
  exit 1
fi

mkdir -p "$(dirname "$WT")"

GIT_DIR=$(git -C "$ROOT" rev-parse --absolute-git-dir)
EXCLUDE_FILE="$GIT_DIR/info/exclude"
if ! grep -Fxq "/.agent-worktrees/" "$EXCLUDE_FILE" 2>/dev/null; then
  printf '\n/.agent-worktrees/\n' >> "$EXCLUDE_FILE"
fi

git worktree add -b "$BRANCH" "$WT" "$BASE_REF"
mkdir -p "$WT/specs" "$WT/.codex-flow/$ID" "$WT/artifacts"

if ! grep -Fxq "/.codex-flow/" "$EXCLUDE_FILE" 2>/dev/null; then
  printf '/.codex-flow/\n' >> "$EXCLUDE_FILE"
fi

if [ ! -e "$WT/specs/$ID.md" ]; then
  cp "$SCRIPT_DIR/../assets/spec-template.md" "$WT/specs/$ID.md"
  sed -i.bak "s/<ID>/$ID/g" "$WT/specs/$ID.md"
  rm "$WT/specs/$ID.md.bak"
fi

echo "created story worktree"
echo "branch: $BRANCH"
echo "base: $BASE_REF"
echo "path: $WT"
echo "next: complete $WT/specs/$ID.md"
