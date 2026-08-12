#!/usr/bin/env bash
# init-verifier.sh - scaffold scripts/verify-project.sh from detected stack markers.
#
# The delivery flows treat scripts/verify-project.sh as the only definition of
# done. This scaffold gives a repository a working starting point; the project
# owns it afterwards and should tighten it as real checks appear.
#
# Usage:
#   init-verifier.sh [--root <path>] [--force] [--print]
#
#   --root <path>  repository to scaffold, default: the enclosing Git root, then $PWD
#   --force        overwrite an existing verifier
#   --print        write the generated verifier to stdout and change nothing
#
# Never overwrites an existing verifier unless --force is given.
set -euo pipefail

ROOT_ARG=""
FORCE=0
PRINT_ONLY=0

usage() {
  echo "usage: init-verifier.sh [--root <path>] [--force] [--print]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      ROOT_ARG=$2
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --print)
      PRINT_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -n "$ROOT_ARG" ]; then
  [ -d "$ROOT_ARG" ] || {
    echo "not a directory: $ROOT_ARG" >&2
    exit 2
  }
  cd "$ROOT_ARG"
fi

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT"

has_npm_script() {
  if command -v node >/dev/null 2>&1; then
    node -e 'const p=require("./package.json"); process.exit(p.scripts && p.scripts[process.argv[1]] ? 0 : 1)' "$1"
    return $?
  fi
  grep -q "\"$1\"[[:space:]]*:" package.json
}

STACKS=""
CHECKS=""

add_stack() {
  if [ -z "$STACKS" ]; then
    STACKS=$1
  else
    STACKS="$STACKS, $1"
  fi
}

add_check() {
  CHECKS="$CHECKS$1
"
}

if [ -f Cargo.toml ]; then
  add_stack "Rust"
  add_check 'cargo fmt --check --all'
  add_check 'cargo clippy --all-targets -- -D warnings'
  add_check 'cargo test'
fi

if [ -f package.json ]; then
  if [ -f pnpm-lock.yaml ]; then
    PACKAGE_MANAGER=pnpm
  elif [ -f yarn.lock ]; then
    PACKAGE_MANAGER=yarn
  elif [ -f bun.lockb ] || [ -f bun.lock ]; then
    PACKAGE_MANAGER=bun
  else
    PACKAGE_MANAGER=npm
  fi
  add_stack "Node.js ($PACKAGE_MANAGER)"
  FOUND_NPM_SCRIPT=0
  for script_name in lint typecheck test build; do
    if has_npm_script "$script_name"; then
      add_check "$PACKAGE_MANAGER run $script_name"
      FOUND_NPM_SCRIPT=1
    else
      add_check "# $PACKAGE_MANAGER run $script_name"
    fi
  done
  if [ "$FOUND_NPM_SCRIPT" -eq 0 ]; then
    add_check "# no lint, typecheck, test, or build script found in package.json"
  fi
fi

if [ -f go.mod ]; then
  add_stack "Go"
  add_check 'test -z "$(gofmt -l .)" || { gofmt -l . >&2; exit 1; }'
  add_check 'go vet ./...'
  add_check 'go test ./...'
fi

if [ -f pom.xml ]; then
  add_stack "Java (Maven)"
  if [ -f mvnw ]; then
    add_check './mvnw -B verify'
  else
    add_check 'mvn -B verify'
  fi
fi

if [ -f build.gradle ] || [ -f build.gradle.kts ]; then
  add_stack "Java (Gradle)"
  if [ -f gradlew ]; then
    add_check './gradlew --no-daemon build'
  else
    add_check 'gradle --no-daemon build'
  fi
fi

if [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.cfg ]; then
  add_stack "Python"
  if command -v uv >/dev/null 2>&1; then
    add_check 'uv run pytest -q'
  else
    add_check 'pytest -q'
  fi
  add_check '# ruff check .'
  add_check '# mypy .'
fi

if ls ./*.sln >/dev/null 2>&1 || ls ./*.csproj >/dev/null 2>&1; then
  add_stack ".NET"
  add_check 'dotnet format --verify-no-changes'
  add_check 'dotnet test'
fi

if [ -z "$CHECKS" ]; then
  STACKS="none detected"
  add_check '# TODO: replace this with the real lint, typecheck, test, and build commands.'
  add_check 'echo "no verification commands configured yet" >&2'
  add_check 'exit 1'
fi

TARGET="$ROOT/scripts/verify-project.sh"

generate() {
  cat <<EOF
#!/usr/bin/env bash
# verify-project.sh - the single definition of done for this repository.
#
# Every delivery-flow stage, the pre-commit hook, and CI run this one command.
# Exit 0 means the story is verifiable; any non-zero exit stops the flow.
# Detected stacks at scaffold time: $STACKS
set -euo pipefail

ROOT=\$(git rev-parse --show-toplevel)
cd "\$ROOT"

$CHECKS
echo "VERIFY PASSED \$(git rev-parse --short HEAD)"
EOF
}

if [ "$PRINT_ONLY" -eq 1 ]; then
  generate
  exit 0
fi

if [ -e "$TARGET" ] && [ "$FORCE" -eq 0 ]; then
  echo "keeping the existing verifier: $TARGET"
  echo "pass --force to overwrite it, or --print to preview the generated one"
  exit 0
fi

mkdir -p "$ROOT/scripts"
generate >"$TARGET"
chmod +x "$TARGET"

echo "wrote $TARGET"
echo "detected stacks: $STACKS"
echo "next: review the commands, run scripts/verify-project.sh, then install the flow's pre-commit hook"
