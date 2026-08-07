#!/usr/bin/env bash
set -u

INPUT=$(cat)
FILE_PATH=""

if command -v jq >/dev/null 2>&1; then
  FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
elif command -v python3 >/dev/null 2>&1; then
  FILE_PATH=$(printf '%s' "$INPUT" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))' 2>/dev/null) || exit 0
elif command -v node >/dev/null 2>&1; then
  FILE_PATH=$(printf '%s' "$INPUT" | node -e 'let s=""; process.stdin.on("data", c => s += c).on("end", () => { try { process.stdout.write(JSON.parse(s).tool_input?.file_path || ""); } catch {} });' 2>/dev/null) || exit 0
else
  exit 0
fi

[ -n "$FILE_PATH" ] || exit 0
ROOT="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$ROOT" ]; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
fi

if [ -x "$ROOT/scripts/format-file.sh" ]; then
  "$ROOT/scripts/format-file.sh" "$FILE_PATH" >/dev/null 2>&1 || true
fi
exit 0
