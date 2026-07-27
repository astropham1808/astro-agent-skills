#!/usr/bin/env bash
# new-story.sh AL-161 — bootstrap a worktree from fresh main
set -euo pipefail
ID=${1:?usage: new-story.sh <STORY-ID>}
git checkout main && git pull --ff-only origin main
claude --worktree "$ID"   # branch: worktree-$ID
