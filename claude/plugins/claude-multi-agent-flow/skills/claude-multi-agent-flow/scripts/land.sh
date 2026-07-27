#!/usr/bin/env bash
# land.sh <STORY-ID> - rebase onto fresh base, re-verify, open the PR.
#
# Opens a pull request. It does not merge: a human does that, always.
#
# Landing is serialised on one lock, because the first branch to merge
# invalidates the base of every other branch in flight. Two stories rebasing and
# verifying against the same base at the same time means one of them verified
# against a base that no longer exists by the time it is reviewed.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/agentflow-lib.sh"

ID=${1:-}; [ -n "$ID" ] || af_die "usage: land.sh <STORY-ID>"

af_require git gh
af_load_config

berth=$(af_berth_for_story "$ID") || af_die "no berth for $ID"
WT=${berth%%$'\t'*}
BRANCH=${berth##*$'\t'}

af_claim "landing" "$ID" || af_die "another story is landing. Wait for it, then retry."
trap 'af_release landing "$ID" >/dev/null 2>&1 || true' EXIT

af_say "fetching origin/$BASE"
git -C "$WT" fetch -q origin "$BASE"

behind=$(git -C "$WT" rev-list --count "$BRANCH..origin/$BASE")
if [ "$behind" -gt 0 ]; then
  af_say "rebasing $BRANCH onto origin/$BASE ($behind commit(s) behind)"
  if ! git -C "$WT" rebase "origin/$BASE"; then
    af_die "rebase stopped with conflicts in $WT.
Resolve them there, run 'git rebase --continue', then run land.sh again."
  fi
else
  af_say "$BRANCH is already on top of origin/$BASE"
fi

# Rebasing moved the commits, so the previous verify result no longer describes
# this code. Re-run it, always.
af_say "verifying against the new base"
if ! ( cd "$WT" && "./$VERIFY" ) > "$WT/notes/$ID-verify.log" 2>&1; then
  af_say "FAILED $ID after rebase"
  tail -30 "$WT/notes/$ID-verify.log"
  exit 1
fi
af_say "verify passed"

# Every step from here reports its own failure. This script deliberately does
# not run under `set -e`, so a command that fails silently would otherwise fall
# through to the success message below and claim a PR exists when it does not.
git -C "$WT" push -q -u origin "$BRANCH" --force-with-lease \
  || af_die "push of $BRANCH failed. Nothing was opened."

( cd "$WT" && gh pr create --base "$BASE" --head "$BRANCH" --fill ) \
  || af_die "$BRANCH is pushed and verified, but 'gh pr create' failed.
Open the PR by hand, or fix gh (gh auth login) and run land.sh again."

af_say ""
af_say "PR open for $ID. A human reviews and merges."
af_say "After the merge, free what this story was holding:"
af_say "  scripts/claim.sh drop $ID"
af_say "  git worktree remove $WT"
