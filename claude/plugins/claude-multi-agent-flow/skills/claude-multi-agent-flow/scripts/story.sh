#!/usr/bin/env bash
# story.sh AL-161 — build -> review -> fix -> verify -> PR (human merges)
set -uo pipefail
ID=${1:?usage: story.sh <STORY-ID>}
ROOT=$(git rev-parse --show-toplevel)
WT="$ROOT/.claude/worktrees/$ID"
# Your source-of-truth query target, e.g. collection://<uuid> for Notion, or a Jira JQL.
COLLECTION="${SOT_COLLECTION:?set SOT_COLLECTION to your backlog source of truth}"

run_claude() {
  claude -p "$1" --output-format stream-json --verbose --max-turns "${2:-30}" \
    | tee -a "$ROOT/notes/$ID-trace.jsonl" \
    | jq -r 'if .type=="system" then "> start: \(.model // "")"
             elif .type=="assistant" then (.message.content[]? | select(.type=="tool_use")
                  | "  * \(.name): \(.input.file_path // .input.command // "")")
             elif .type=="result" then "= done $\(.total_cost_usd // 0) / \(.num_turns // 0) turns"
             else empty end'
}

[ -d "$WT" ] || { echo "no worktree for $ID — run new-story.sh first"; exit 1; }
cd "$WT"

echo "== 1/4 build"
run_claude "Run ONE SQL query on $COLLECTION for story $ID (Story, Acceptance Criteria, Epic, Priority). Write specs/$ID.md with machine-readable Done-when commands. Fetch nothing else from Notion. Then implement it per CLAUDE.md. Commit when tests pass." 40

echo "== 2/4 review (codex, read-only sandbox)"
codex exec -p review -o "$ROOT/notes/$ID-review.md" \
  "Review git diff main...worktree-$ID against specs/$ID.md. Findings as a markdown checklist. Do not edit code."

echo "== 3/4 fix (max 1 round)"
run_claude "Read notes/$ID-review.md. Address only valid findings. Max 1 round — if something needs a design decision, stop and list it." 20

echo "== 4/4 verify"
if "$ROOT/scripts/verify.sh" > "$ROOT/notes/$ID-verify.log" 2>&1; then
  gh pr create --base main --head "worktree-$ID" --fill
  echo "READY $ID — notes/$ID-verify.log + PR open. Human reviews and merges."
else
  echo "FAILED $ID"; tail -30 "$ROOT/notes/$ID-verify.log"; exit 1
fi
