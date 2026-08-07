#!/usr/bin/env bash
# verify.sh — the ONLY definition of done for a target project.
# Keep stack-specific commands in the target project's verifier.
set -euo pipefail

TARGET=${1:-.}
cd "$TARGET"
ROOT=$(git rev-parse --show-toplevel)

if [ -x "$ROOT/scripts/verify-project.sh" ]; then
  exec "$ROOT/scripts/verify-project.sh"
fi

echo "missing executable project verifier: $ROOT/scripts/verify-project.sh" >&2
echo "configure the project's lint, typecheck, test, and build checks there" >&2
exit 2
