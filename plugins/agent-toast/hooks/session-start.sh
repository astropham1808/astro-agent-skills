#!/usr/bin/env bash
# Records session start time so notify-stop.sh can compute task duration.
# Keyed by CLAUDE_CODE_SESSION_ID so multiple concurrent sessions don't collide.
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-default}"
echo "$(date +%s)" > "/tmp/agent-toast-${SESSION_ID}.start"
