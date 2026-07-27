#!/usr/bin/env bash
# board.sh - one line per story in flight: where it is, what it costs, what it
# is holding, and whether it needs a rebase.
#
# The truth about which berths exist is `git worktree list --porcelain`, never a
# side file that can drift from it. Everything else is derived from artifacts on
# disk, so the board cannot claim a story is further along than its evidence.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/agentflow-lib.sh"

af_require git
af_load_config
ROOT=$(af_root)

# Phase is whatever the artifacts can prove, in order. No agent self-reports here.
phase_of() {
  local wt=$1 id=$2 branch=$3 ahead
  [ -f "$wt/specs/$id.md" ]        || { echo spec;   return; }
  ahead=$(git -C "$wt" rev-list --count "$BASE..$branch" 2>/dev/null || echo 0)
  [ "$ahead" -gt 0 ]               || { echo build;  return; }
  [ -f "$wt/notes/$id-review.md" ] || { echo review; return; }
  if [ -f "$wt/notes/$id-verify.log" ] && grep -q "VERIFY PASSED" "$wt/notes/$id-verify.log" 2>/dev/null; then
    echo ready
  else
    echo verify
  fi
}

cost_of() {
  local trace=$1
  [ -f "$trace" ] || { printf '%s' "-"; return; }
  command -v jq >/dev/null 2>&1 || { printf '%s' "?"; return; }
  jq -R 'fromjson? // empty | .total_cost_usd // empty' "$trace" 2>/dev/null \
    | awk '{s+=$1} END{ if (s>0) printf "$%.2f", s; else printf "-" }'
}

locks_of() {
  local id=$1 out="" res holder
  [ ${#EXCLUSIVE[@]} -eq 0 ] && { printf '%s' "-"; return; }
  for res in "${EXCLUSIVE[@]}"; do
    holder=$(af_lock_holder "$res" || true)
    [ "$holder" = "$id" ] && out="$out,$(basename "$res")"
  done
  if [ -n "$out" ]; then printf '%s' "${out#,}"; else printf '%s' "-"; fi
}

git fetch -q origin "$BASE" 2>/dev/null || af_warn "could not fetch origin/$BASE, drift column may be stale"

printf '%-10s %-22s %-8s %-7s %-6s %s\n' STORY BRANCH PHASE BEHIND COST HOLDS
found=0
ids=(); branches=()
while IFS= read -r wt; do
  [ -n "$wt" ] || continue
  branch=$(af_worktree_branch "$wt"); [ -n "$branch" ] || continue
  id=$(af_story_of "$branch"); [ -n "$id" ] || id="?"
  behind=$(git -C "$wt" rev-list --count "$branch..origin/$BASE" 2>/dev/null || echo "?")
  printf '%-10s %-22s %-8s %-7s %-6s %s\n' \
    "$id" "$branch" "$(phase_of "$wt" "$id" "$branch")" "$behind" \
    "$(cost_of "$wt/notes/$id-trace.jsonl")" "$(locks_of "$id")"
  ids+=("$id"); branches+=("$branch")
  found=$((found + 1))
done < <(af_berths)

[ "$found" -gt 0 ] || af_say "(no berths open)"

printf '\n%s berth(s), cap %s. BEHIND is commits on origin/%s not yet in the branch.\n' \
  "$found" "$WIP_CAP" "$BASE"

# Counted without `ls`, whose failure on a lock directory that does not exist yet
# would take the whole script down under `set -e` with `pipefail`, silently
# truncating everything below.
lockdir=$(af_lockdir); held=0
[ -d "$lockdir" ] && held=$(find "$lockdir" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
[ "$held" = "0" ] || printf 'locks held: %s (scripts/claim.sh list)\n' "$held"

# Files two branches in flight have both changed. EXCLUSIVE only covers what
# somebody thought to declare ahead of time, and the files that actually collide
# are usually whichever two stories happened to land in the same week. This check
# needs no foresight: ask what the diffs really touch, and compare them.
overlap=0
n=${#branches[@]}
for ((i = 0; i < n; i++)); do
  for ((j = i + 1; j < n; j++)); do
    both=$(comm -12 \
      <(git diff --name-only "$BASE...${branches[i]}" 2>/dev/null | sort) \
      <(git diff --name-only "$BASE...${branches[j]}" 2>/dev/null | sort))
    [ -n "$both" ] || continue
    if [ "$overlap" = 0 ]; then
      printf '\noverlapping edits (a merge conflict here is certain, not likely):\n'
      overlap=1
    fi
    printf '  %s and %s both change:\n' "${ids[i]}" "${ids[j]}"
    printf '%s\n' "$both" | sed 's/^/    /'
  done
done
