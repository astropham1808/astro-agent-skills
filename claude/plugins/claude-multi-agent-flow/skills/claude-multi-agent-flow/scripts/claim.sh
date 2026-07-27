#!/usr/bin/env bash
# claim.sh - hold, release, and inspect the resources only one story may touch.
#
#   claim.sh list
#   claim.sh take    <resource> <STORY-ID>
#   claim.sh release <resource> <STORY-ID>
#   claim.sh drop    <STORY-ID>            # release everything that story holds
#
# A resource is anything two berths cannot use at once: a fixed dev-server port,
# a generated file, a pair of files that must change together. Declare them in
# EXCLUSIVE in .agentflow.conf. Nothing enforces this at the filesystem level;
# the lock is how agents and humans find out before they collide, not after.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/agentflow-lib.sh"

af_load_config
cmd=${1:-list}

case "$cmd" in
  list)
    if [ ${#EXCLUSIVE[@]} -eq 0 ]; then
      af_say "no exclusive resources declared in .agentflow.conf"
      exit 0
    fi
    printf '%-44s %s\n' "RESOURCE" "HELD BY"
    for res in "${EXCLUSIVE[@]}"; do
      holder=$(af_lock_holder "$res" || true)
      printf '%-44s %s\n' "$res" "${holder:--}"
    done
    ;;
  take)
    res=${2:?usage: claim.sh take <resource> <STORY-ID>}
    id=${3:?usage: claim.sh take <resource> <STORY-ID>}
    af_claim "$res" "$id" && af_say "$id holds $res"
    ;;
  release)
    res=${2:?usage: claim.sh release <resource> <STORY-ID>}
    id=${3:?usage: claim.sh release <resource> <STORY-ID>}
    af_release "$res" "$id" && af_say "$id released $res"
    ;;
  drop)
    id=${2:?usage: claim.sh drop <STORY-ID>}
    af_release_all "$id"
    af_say "$id holds nothing now"
    ;;
  *)
    af_die "usage: claim.sh list | take <res> <id> | release <res> <id> | drop <id>"
    ;;
esac
