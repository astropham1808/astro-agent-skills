#!/usr/bin/env bash
# verify.sh - resolve and run the definition of done for a target project.
#
# Resolution order:
#   1. $PROJECT_VERIFIER, absolute or relative to the repository root
#   2. <repository root>/scripts/verify-project.sh
#   3. generic checks detected from the repository's stack markers
#
# Keep stack-specific commands in the target project's verifier. The generic
# checks exist so a repository can run the flow before it owns one, not as a
# replacement for a project-owned definition of done.
set -euo pipefail

TARGET=${1:-.}
cd "$TARGET"
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"

resolve_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "$ROOT/$1" ;;
  esac
}

if [ -n "${PROJECT_VERIFIER:-}" ]; then
  VERIFIER=$(resolve_path "$PROJECT_VERIFIER")
  if [ ! -f "$VERIFIER" ]; then
    echo "PROJECT_VERIFIER does not exist: $VERIFIER" >&2
    exit 2
  fi
  if [ ! -x "$VERIFIER" ]; then
    echo "PROJECT_VERIFIER is not executable: $VERIFIER" >&2
    echo "run: chmod +x \"$VERIFIER\"" >&2
    exit 2
  fi
  exec "$VERIFIER"
fi

PROJECT_SCRIPT="$ROOT/scripts/verify-project.sh"
if [ -x "$PROJECT_SCRIPT" ]; then
  exec "$PROJECT_SCRIPT"
fi
if [ -f "$PROJECT_SCRIPT" ]; then
  echo "found $PROJECT_SCRIPT but it is not executable" >&2
  echo "run: chmod +x scripts/verify-project.sh" >&2
  exit 2
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
  go vet ./...
  go test ./...
  RAN=1
fi

if [ -f pom.xml ]; then
  if [ -f ./mvnw ] && [ ! -x ./mvnw ]; then
    echo "found ./mvnw but it is not executable; run: chmod +x mvnw" >&2
  fi
  if [ -x ./mvnw ]; then
    MAVEN=./mvnw
  elif command -v mvn >/dev/null 2>&1; then
    MAVEN=mvn
  else
    echo "pom.xml exists but neither ./mvnw nor mvn is available" >&2
    exit 2
  fi
  "$MAVEN" -B verify
  RAN=1
fi

if [ -f build.gradle ] || [ -f build.gradle.kts ]; then
  if [ -f ./gradlew ] && [ ! -x ./gradlew ]; then
    echo "found ./gradlew but it is not executable; run: chmod +x gradlew" >&2
  fi
  if [ -x ./gradlew ]; then
    GRADLE=./gradlew
  elif command -v gradle >/dev/null 2>&1; then
    GRADLE=gradle
  else
    echo "a Gradle build exists but neither ./gradlew nor gradle is available" >&2
    exit 2
  fi
  "$GRADLE" --no-daemon build
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

if ls ./*.sln >/dev/null 2>&1 || ls ./*.csproj >/dev/null 2>&1; then
  command -v dotnet >/dev/null 2>&1 || {
    echo "a .NET project exists but dotnet is unavailable" >&2
    exit 2
  }
  dotnet test
  RAN=1
fi

if [ "$RAN" -eq 0 ]; then
  echo "no generic verification checks were discovered" >&2
  echo "create executable scripts/verify-project.sh with project-specific checks," >&2
  echo "or scaffold one with the project-setup skill's scripts/init-verifier.sh" >&2
  exit 2
fi

echo "VERIFY PASSED $(git rev-parse --short HEAD)"
