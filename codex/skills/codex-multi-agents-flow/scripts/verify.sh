#!/usr/bin/env bash
set -euo pipefail

TARGET=${1:-.}
cd "$TARGET"
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"

if [ -x "$ROOT/scripts/verify-project.sh" ]; then
  exec "$ROOT/scripts/verify-project.sh"
fi

RAN=0

if [ -f Cargo.toml ]; then
  command -v cargo >/dev/null 2>&1 || {
    echo "Cargo.toml exists but cargo is unavailable" >&2
    exit 2
  }
  cargo fmt --check --all
  cargo clippy --all-targets -- -D warnings
  cargo test
  RAN=1
fi

if [ -f package.json ]; then
  command -v node >/dev/null 2>&1 || {
    echo "package.json exists but node is unavailable" >&2
    exit 2
  }

  if [ -f pnpm-lock.yaml ]; then
    PACKAGE_MANAGER=pnpm
  elif [ -f yarn.lock ]; then
    PACKAGE_MANAGER=yarn
  elif [ -f bun.lockb ] || [ -f bun.lock ]; then
    PACKAGE_MANAGER=bun
  else
    PACKAGE_MANAGER=npm
  fi

  command -v "$PACKAGE_MANAGER" >/dev/null 2>&1 || {
    echo "package manager unavailable: $PACKAGE_MANAGER" >&2
    exit 2
  }

  for script_name in lint typecheck test; do
    if node -e 'const p=require("./package.json"); process.exit(p.scripts && p.scripts[process.argv[1]] ? 0 : 1)' "$script_name"; then
      CI=1 "$PACKAGE_MANAGER" run "$script_name"
      RAN=1
    fi
  done
fi

if [ -f go.mod ]; then
  command -v go >/dev/null 2>&1 || {
    echo "go.mod exists but go is unavailable" >&2
    exit 2
  }
  UNFORMATTED=$(gofmt -l .)
  if [ -n "$UNFORMATTED" ]; then
    echo "unformatted Go files:" >&2
    echo "$UNFORMATTED" >&2
    exit 1
  fi
  go test ./...
  RAN=1
fi

if [ -f pyproject.toml ] && { [ -d tests ] || [ -f pytest.ini ]; }; then
  if command -v uv >/dev/null 2>&1; then
    uv run pytest -q
  elif command -v pytest >/dev/null 2>&1; then
    pytest -q
  else
    echo "Python tests detected but neither uv nor pytest is available" >&2
    exit 2
  fi
  RAN=1
fi

if [ "$RAN" -eq 0 ]; then
  echo "no generic verification checks were discovered" >&2
  echo "create executable scripts/verify-project.sh with project-specific checks" >&2
  exit 2
fi

echo "VERIFY PASSED $(git rev-parse --short HEAD)"

