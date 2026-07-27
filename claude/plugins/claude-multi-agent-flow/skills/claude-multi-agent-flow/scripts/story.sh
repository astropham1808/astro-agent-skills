#!/usr/bin/env bash
# story.sh <STORY-ID> [--dry-run] - spec, build, review, fix, verify.
# It never merges. A human does that.
#
# Never run a bare `claude -p` from a pipeline: every model step here streams
# live, appends to a trace, and prints what it spent.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/agentflow-lib.sh"

ID=${1:-}; [ -n "$ID" ] || af_die "usage: story.sh <STORY-ID> [--dry-run]"
DRY=${2:-}

af_require git claude codex jq
af_load_config

# Which berth owns this story is a question for git, not for a naming guess.
berth=$(af_berth_for_story "$ID") || af_die "no berth for $ID. Run: scripts/new-story.sh $ID <owner>"
WT=${berth%%$'\t'*}
BRANCH=${berth##*$'\t'}
NOTES="$WT/notes"
mkdir -p "$NOTES"

REVIEWER=$(af_reviewer_for "$BRANCH")
af_say "story   $ID"
af_say "berth   $WT"
af_say "branch  $BRANCH"
af_say "review  $REVIEWER$([ "$REVIEWER" = "$DEEP_REVIEW_PROFILE" ] && echo '  (diff touches a risky path)')"

# Warn about exclusive resources this diff already touches without a lock.
while IFS= read -r res; do
  [ -n "$res" ] || continue
  holder=$(af_lock_holder "$res" || true)
  if [ -z "$holder" ]; then
    af_warn "$ID edits '$res' without holding it: scripts/claim.sh take '$res' $ID"
  elif [ "$holder" != "$ID" ]; then
    af_warn "$ID edits '$res' but $holder holds it. Collision at merge is certain."
  fi
done < <(af_conflicts_for "$BRANCH")

if [ "$DRY" = "--dry-run" ]; then
  af_say ""
  af_say "dry run, nothing executed."
  exit 0
fi

run_claude() {
  ( cd "$WT" && claude -p "$1" --output-format stream-json --verbose --max-turns "${2:-30}" ) \
    | tee -a "$NOTES/$ID-trace.jsonl" \
    | jq -r 'if .type=="system" then "> start: \(.model // "")"
             elif .type=="assistant" then (.message.content[]? | select(.type=="tool_use")
                  | "  * \(.name): \(.input.file_path // .input.command // "")")
             elif .type=="result" then "= done $\(.total_cost_usd // 0) / \(.num_turns // 0) turns"
             else empty end'
}

af_say ""
af_say "== 1/4 spec + build"
run_claude "Run exactly ONE query against $SOT for story $ID and write specs/$ID.md from it: story, acceptance criteria, epic, priority. Every Done-when line must be a runnable command. Fetch nothing else from the source of truth. Then implement the story following the repository's own instructions file. Commit when tests pass." 40

af_say ""
af_say "== 2/4 review ($REVIEWER, read-only)"
# Checked explicitly: this script does not run under `set -e`, and a review that
# failed to run would otherwise leave step 3 reading a stale or absent file and
# calling that "no findings".
codex exec -p "$REVIEWER" -C "$WT" -o "$NOTES/$ID-review.md" \
  "Review the diff of git diff $BASE...$BRANCH against specs/$ID.md. Report findings as a markdown checklist, most severe first. Do NOT edit any code." \
  || af_die "the $REVIEWER step failed. Nothing was fixed; $ID is untouched since the build."
[ -s "$NOTES/$ID-review.md" ] || af_die "$REVIEWER wrote no findings file. Treating that as a failed review, not as an approval."

af_say ""
af_say "== 3/4 fix (one round)"
run_claude "Read notes/$ID-review.md. Address only the findings that are valid. This is a single round: if a finding needs a design decision, stop and list it instead of guessing." 20

af_say ""
af_say "== 4/4 verify"
if ( cd "$WT" && "./$VERIFY" ) > "$NOTES/$ID-verify.log" 2>&1; then
  af_say "VERIFIED $ID"
  af_say "  log:  $NOTES/$ID-verify.log"
  af_say "  next: scripts/land.sh $ID"
else
  af_say "FAILED $ID"
  tail -30 "$NOTES/$ID-verify.log"
  exit 1
fi
