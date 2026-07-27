#!/usr/bin/env bash
# close-story.sh <STORY-ID> [--apply] - retire a berth after the human merged it.
#
# The last step of the flow, and the only one that deletes anything. It never
# merges and it never makes a worktree "look clean" in order to remove it:
# every check below is a reason to stop, not a thing to work around.
#
# Previews by default. --apply is the human saying yes to the preview.
#
# Order is deliberate. Locks are released only after the worktree is actually
# gone, so a removal that fails does not hand a resource to the next story while
# this one is still sitting on disk holding it.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/agentflow-lib.sh"

ID=${1:-}; [ -n "$ID" ] || af_die "usage: close-story.sh <STORY-ID> [--apply]"
APPLY=${2:-}
[ -z "$APPLY" ] || [ "$APPLY" = "--apply" ] || af_die "unknown argument: $APPLY"

af_require git gh jq
af_load_config

berth=$(af_berth_for_story "$ID") || af_die "no berth for $ID. Nothing to close."
WT=${berth%%$'\t'*}
BRANCH=${berth##*$'\t'}

# The primary worktree, not af_root: this script can legitimately be run from
# inside a berth, where af_root is that berth. Both mutating commands below need
# to run from somewhere that still exists after the removal, and the guard needs
# to compare against the real primary rather than wherever we happen to be.
PRIMARY=$(git worktree list --porcelain | awk '/^worktree /{print substr($0,10); exit}')
PRIMARY=$(cd "$PRIMARY" && pwd -P) || af_die "cannot resolve the primary worktree"

# Resolve symlinks on both sides before comparing: a berth reached through a
# symlinked path would otherwise not match the tree it actually is.
WT=$(cd "$WT" 2>/dev/null && pwd -P) || af_die "berth path for $ID does not exist"
[ "$WT" != "$PRIMARY" ] || af_die "refusing to remove the primary worktree: $PRIMARY"

# --- the merge gate ----------------------------------------------------------
# A merged PR is the only thing that authorises any of this. Ask GitHub, not the
# local repository, and not the person running the script.

pr=$(gh pr view "$BRANCH" --json headRefName,baseRefName,url,state,mergedAt 2>/dev/null) \
  || af_die "no pull request found for $BRANCH.
Nothing was touched. Open one with scripts/land.sh $ID, or close the berth by hand."

pr_head=$(printf '%s' "$pr" | jq -r '.headRefName')
pr_base=$(printf '%s' "$pr" | jq -r '.baseRefName')
pr_url=$(printf '%s' "$pr" | jq -r '.url')
pr_state=$(printf '%s' "$pr" | jq -r '.state')
merged_at=$(printf '%s' "$pr" | jq -r '.mergedAt // ""')

[ "$pr_head" = "$BRANCH" ] \
  || af_die "PR head is $pr_head, not $BRANCH. Refusing to act on a PR that is not this berth's."
[ -n "$merged_at" ] && [ "$merged_at" != "null" ] \
  || af_die "$pr_url is $pr_state, not merged. A human merges first; this script only cleans up after."
[ "$pr_base" = "$BASE" ] \
  || af_warn "PR merged into $pr_base, but BASE is $BASE. Checking ancestry against origin/$pr_base."
base=$pr_base

# --- the local gates ---------------------------------------------------------

dirty=$(git -C "$WT" status --porcelain)
[ -z "$dirty" ] || af_die "berth is dirty, refusing to close it:
$(git -C "$WT" status --short)
The merge is done, so this is work that never reached the PR. Deal with it
first. This script will not reset, clean, stash, or force."

git -C "$WT" fetch -q origin "$base" || af_die "could not fetch origin/$base. Nothing was touched."

# How the branch was merged decides how the branch can be deleted.
if git -C "$WT" merge-base --is-ancestor "$BRANCH" "origin/$base"; then
  merge_kind="merge commit or fast-forward"
  delete_flag="-d"
else
  # Squash and rebase merges rewrite the commits, so the branch tip is not an
  # ancestor of the base and `git branch -d` will refuse it. That is fine, but
  # only once the commits exist somewhere other than this berth.
  local_tip=$(git -C "$WT" rev-parse "$BRANCH")
  remote_tip=$(git -C "$WT" rev-parse --verify --quiet "refs/remotes/origin/$BRANCH") || remote_tip=""
  [ "$remote_tip" = "$local_tip" ] || af_die "$BRANCH is not an ancestor of origin/$base (squash or rebase merge),
and its tip is not on origin either. Deleting it here would be the only copy.
Push it first, or delete the branch by hand once you are sure."
  merge_kind="squash or rebase, tip preserved at origin/$BRANCH"
  delete_flag="-D"
fi

notes="$WT/notes/$ID.md"
[ -f "$notes" ] || af_warn "no notes/$ID.md in the berth.
The flow asks for one on close: what was done, decisions taken, open questions.
Write it before --apply, or lose it with the worktree."

held=""
if [ ${#EXCLUSIVE[@]} -gt 0 ]; then
  for res in "${EXCLUSIVE[@]}"; do
    [ "$(af_lock_holder "$res" || true)" = "$ID" ] && held="$held $res"
  done
fi

# --- report ------------------------------------------------------------------

af_say "story     $ID"
af_say "pr        $pr_url"
af_say "merged    $merged_at into $base"
af_say "how       $merge_kind"
af_say "berth     $WT"
af_say "branch    $BRANCH  (delete with git branch $delete_flag)"
af_say "locks     ${held:-none}"
af_say "remote    origin/$BRANCH kept. Delete it on GitHub if you want it gone."

if [ "$APPLY" != "--apply" ]; then
  af_say ""
  af_say "preview only. Re-run with --apply to remove the berth and the local branch."
  exit 0
fi

# --- apply -------------------------------------------------------------------
# Not under `set -e`: each step reports its own failure, so nothing below can
# fall through to the success message on a command that quietly did nothing.

af_say ""
# From the primary worktree: git refuses to remove the worktree you are standing
# in, and the branch delete needs a tree that outlives this one.
cd "$PRIMARY" || af_die "cannot enter $PRIMARY. Nothing was touched."

git worktree remove -- "$WT" \
  || af_die "could not remove $WT. Locks are untouched and $ID is still open."
af_say "removed berth $WT"

git branch "$delete_flag" -- "$BRANCH" \
  || af_warn "worktree is gone but 'git branch $delete_flag $BRANCH' failed. Delete the branch by hand."

git worktree prune

af_release_all "$ID"
[ -z "$held" ] || af_say "released:$held"

af_say ""
af_say "$ID closed. A berth is free: scripts/board.sh"
