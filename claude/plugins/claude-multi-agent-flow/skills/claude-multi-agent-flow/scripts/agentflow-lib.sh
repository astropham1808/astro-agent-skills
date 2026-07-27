#!/usr/bin/env bash
# agentflow-lib.sh - shared helpers. Sourced by every other script here.
#
# Nothing in this file is project-specific. Everything project-specific lives in
# .agentflow.conf at the repository root, which every script loads through
# af_load_config. See assets/agentflow.conf.example.

# --- config ------------------------------------------------------------------

# Repository root. Inside a linked worktree this is the worktree's own root,
# which is what we want: .agentflow.conf is committed, so every berth has it.
af_root() { git rev-parse --show-toplevel; }

# The directory shared by every worktree of this repository. Locks live here so
# that a berth can see a lock another berth is holding, without committing it.
af_common() {
  local d
  d=$(git rev-parse --git-common-dir)
  case "$d" in /*|?:[\\/]*) printf '%s\n' "$d" ;; *) printf '%s\n' "$(af_root)/$d" ;; esac
}

af_load_config() {
  local root cfg
  root=$(af_root) || return 1
  cfg="$root/.agentflow.conf"
  [ -f "$cfg" ] || af_die "no .agentflow.conf at $root (copy assets/agentflow.conf.example)"

  # Defaults for anything the project chooses not to set.
  PREFIX=""; SOT=""; BASE="main"; WIP_CAP=3
  BRANCH_PATTERN='{owner}/{id}'
  WORKTREE_PATTERN='../{repo}-{id}'
  VERIFY="scripts/verify.sh"
  REVIEW_PROFILE="review"; DEEP_REVIEW_PROFILE="deepreview"; MECH_PROFILE="mech"
  EXCLUSIVE=(); RISKY_PATHS=()

  # shellcheck disable=SC1090
  . "$cfg"

  [ -n "$SOT" ] || af_die "SOT is unset in $cfg. The story spec has no source of truth to read."
}

# --- output ------------------------------------------------------------------

af_die()  { printf 'agentflow: %s\n' "$*" >&2; exit 1; }
af_warn() { printf 'agentflow: %s\n' "$*" >&2; }
af_say()  { printf '%s\n' "$*"; }

# --- naming ------------------------------------------------------------------

# af_expand <pattern> <id> <owner> - fills {id} {owner} {repo} {base}
af_expand() {
  local pat=$1 id=$2 owner=${3:-} repo
  repo=$(basename "$(af_root)")
  pat=${pat//\{id\}/$id}
  pat=${pat//\{owner\}/$owner}
  pat=${pat//\{repo\}/$repo}
  pat=${pat//\{base\}/$BASE}
  printf '%s\n' "$pat"
}

af_branch_for()   { af_expand "$BRANCH_PATTERN" "$1" "$2"; }
af_worktree_for() { af_expand "$WORKTREE_PATTERN" "$1" "$2"; }

# --- worktrees ---------------------------------------------------------------
# git worktree list --porcelain is the truth. Never a side file, never a guess.

# af_worktree_path <branch> - prints the checkout path, empty if not checked out
af_worktree_path() {
  git worktree list --porcelain | awk -v want="refs/heads/$1" '
    /^worktree /  { path = substr($0, 10) }
    /^branch /    { if (substr($0, 8) == want) { print path; exit } }
  '
}

# af_worktree_branch <path> - the inverse
af_worktree_branch() {
  git worktree list --porcelain | awk -v want="$1" '
    /^worktree /  { path = substr($0, 10) }
    /^branch /    { if (path == want) { sub(/^branch refs\/heads\//, ""); print; exit } }
  '
}

# Every worktree except the primary one, one path per line.
af_berths() { git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | tail -n +2; }

af_berth_count() { af_berths | grep -c . || true; }

# af_story_of <branch> - pulls the story id back out of a branch name
af_story_of() {
  local b=$1
  printf '%s\n' "$b" | grep -oE "${PREFIX}[0-9]+" | head -1
}

# af_berth_for_story <id> - "<path>\t<branch>" for the berth owning a story.
# Found by asking git, so it works whoever created the worktree and whatever
# the owner prefix on the branch happens to be.
af_berth_for_story() {
  local id=$1 wt branch
  while IFS= read -r wt; do
    [ -n "$wt" ] || continue
    branch=$(af_worktree_branch "$wt") || continue
    [ -n "$branch" ] || continue
    if [ "$(af_story_of "$branch")" = "$id" ]; then
      printf '%s\t%s\n' "$wt" "$branch"; return 0
    fi
  done < <(af_berths)
  return 1
}

# --- locks -------------------------------------------------------------------
# A lock is a directory, because mkdir is atomic. The holder's story id is
# written inside it. Locks are per-repository, not per-worktree.

af_lockdir() { printf '%s\n' "$(af_common)/agentflow/locks"; }

af_lockpath() {
  local safe=${1//\//_}
  printf '%s\n' "$(af_lockdir)/${safe//:/_}"
}

af_lock_holder() {
  local p; p=$(af_lockpath "$1")
  [ -d "$p" ] && cat "$p/owner" 2>/dev/null
}

# af_claim <resource> <story-id> - 0 if we hold it now, 1 if someone else does
af_claim() {
  local res=$1 id=$2 p holder
  p=$(af_lockpath "$res")
  mkdir -p "$(af_lockdir)"
  if mkdir "$p" 2>/dev/null; then
    printf '%s\n' "$id" > "$p/owner"
    date -u +%Y-%m-%dT%H:%M:%SZ > "$p/since"
    return 0
  fi
  holder=$(cat "$p/owner" 2>/dev/null || echo "?")
  [ "$holder" = "$id" ] && return 0
  af_warn "'$res' is held by $holder"
  return 1
}

af_release() {
  local res=$1 id=$2 p holder
  p=$(af_lockpath "$res")
  [ -d "$p" ] || return 0
  holder=$(cat "$p/owner" 2>/dev/null || echo "?")
  if [ "$holder" != "$id" ]; then
    af_warn "refusing to release '$res': held by $holder, not $id"
    return 1
  fi
  rm -rf "$p"
}

# Drop every lock a story holds. Called when a story lands.
af_release_all() {
  local id=$1 p holder
  for p in "$(af_lockdir)"/*; do
    [ -d "$p" ] || continue
    holder=$(cat "$p/owner" 2>/dev/null || echo "")
    [ "$holder" = "$id" ] && rm -rf "$p"
  done
  return 0
}

# --- routing -----------------------------------------------------------------

# af_reviewer_for <branch> - deep reviewer if the diff touches a risky path.
# Size picks the builder; risk picks the reviewer. They are different questions.
af_reviewer_for() {
  local branch=$1 files p
  [ ${#RISKY_PATHS[@]} -eq 0 ] && { printf '%s\n' "$REVIEW_PROFILE"; return; }
  files=$(git diff --name-only "$BASE...$branch" 2>/dev/null) || files=""
  for p in "${RISKY_PATHS[@]}"; do
    if printf '%s\n' "$files" | grep -q "^$p"; then
      printf '%s\n' "$DEEP_REVIEW_PROFILE"; return
    fi
  done
  printf '%s\n' "$REVIEW_PROFILE"
}

# af_conflicts_for <branch> - exclusive resources this branch's diff touches
af_conflicts_for() {
  local branch=$1 files res part hit
  [ ${#EXCLUSIVE[@]} -eq 0 ] && return 0
  files=$(git diff --name-only "$BASE...$branch" 2>/dev/null) || return 0
  for res in "${EXCLUSIVE[@]}"; do
    case "$res" in
      port-*|*:*) continue ;;   # not a path, cannot be inferred from a diff
    esac
    # A pair joined by '+' is one resource: the two files must change together,
    # so touching either half is touching the resource.
    hit=0
    while IFS= read -r part; do
      [ -n "$part" ] || continue
      printf '%s\n' "$files" | grep -qx "$part" && hit=1
    done < <(printf '%s\n' "${res//+/$'\n'}")
    [ "$hit" = 1 ] && printf '%s\n' "$res"
  done
  return 0
}

# --- prerequisites -----------------------------------------------------------

af_require() {
  local missing=""
  for c in "$@"; do command -v "$c" >/dev/null 2>&1 || missing="$missing $c"; done
  [ -z "$missing" ] || af_die "missing required command(s):$missing"
}
