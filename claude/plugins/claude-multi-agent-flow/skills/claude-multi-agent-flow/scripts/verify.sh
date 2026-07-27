#!/usr/bin/env bash
# verify.sh — the ONLY definition of done. Exit 0 = done. Edit per stack.
set -e
cargo fmt --check --all
cargo clippy -q --all-targets -- -D warnings
cargo test -q
npm run typecheck
npm run test -- --run
echo "VERIFY PASSED $(git rev-parse --short HEAD)"
