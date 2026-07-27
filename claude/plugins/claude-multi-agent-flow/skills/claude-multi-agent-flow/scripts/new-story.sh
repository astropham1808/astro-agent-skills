#!/usr/bin/env bash
# new-story.sh <STORY-ID> <owner> - open a berth for one story.
#
# Branches from origin/<base> without checking anything out in the primary
# worktree, so opening a berth never disturbs work already in progress there.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/agentflow-lib.sh"

ID=${1:-}; OWNER=${2:-}
[ -n "$ID" ] && [ -n "$OWNER" ] || af_die "usage: new-story.sh <STORY-ID> <owner>"

af_require git
af_load_config

BRANCH=$(af_branch_for "$ID" "$OWNER")
WT=$(af_worktree_for "$ID" "$OWNER")

existing=$(af_worktree_path "$BRANCH")
[ -z "$existing" ] || af_die "$BRANCH is already checked out at $existing"

count=$(af_berth_count)
if [ "$count" -ge "$WIP_CAP" ]; then
  af_die "WIP cap reached: $count berths open, cap is $WIP_CAP.
Land or close one first. Raise WIP_CAP in .agentflow.conf only if the machine
can actually take another concurrent build."
fi

af_say "fetching origin/$BASE"
git fetch -q origin "$BASE"

af_say "berth  $WT"
af_say "branch $BRANCH  (from origin/$BASE)"
git worktree add -b "$BRANCH" "$WT" "origin/$BASE"

# Hooks live in the shared common dir, so a berth inherits whatever the primary
# worktree has installed. Say so rather than letting it be a surprise.
hook="$(af_common)/hooks/pre-commit"
[ -x "$hook" ] || af_warn "no executable pre-commit hook at $hook.
The expensive checks are meant to run at commit. Install it before building."

af_say ""
af_say "next: open your builder in $WT, then"
af_say "  scripts/story.sh $ID"
