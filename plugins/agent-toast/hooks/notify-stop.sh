#!/usr/bin/env bash
# agent-toast — Stop hook (cross-platform: Windows/WSL, macOS, Linux)
#
# Reads three values that Claude Code populates from the plugin's userConfig:
#   CLAUDE_PLUGIN_OPTION_AGENT_NAME    -- toast title
#   CLAUDE_PLUGIN_OPTION_ICON_PATH     -- absolute PNG path (blank = bundled icon)
#   CLAUDE_PLUGIN_OPTION_BEEP_ENABLED  -- "yes"/"y"/"true"/"1"/"on" (anything else = silent)
#
# CLAUDE_PLUGIN_ROOT points at this plugin's install directory.
#
# Multi-window support:
#   When running multiple Claude Code sessions simultaneously, each notification
#   shows the project directory name so you know which agent finished.
#   Clicking the notification focuses the correct terminal window.

set -u

AGENT_NAME="${CLAUDE_PLUGIN_OPTION_AGENT_NAME:-Agent}"
SESSION_LABEL="${CLAUDE_PLUGIN_OPTION_SESSION_LABEL:-}"
ICON_PATH="${CLAUDE_PLUGIN_OPTION_ICON_PATH:-}"
BEEP_RAW="${CLAUDE_PLUGIN_OPTION_BEEP_ENABLED:-no}"

if [ -z "$ICON_PATH" ]; then
    ICON_PATH="${CLAUDE_PLUGIN_ROOT}/assets/default-icon.png"
fi

SOUND_PATH="${CLAUDE_PLUGIN_ROOT}/assets/notify.wav"
PROJECT_NAME="$(basename "$PWD")"

# Notification title: session label takes priority over agent name.
NOTIFY_TITLE="${SESSION_LABEL:-$AGENT_NAME}"

# Compute elapsed time from session-start.sh timestamp.
NOTIFY_DURATION=""
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
if [ -n "$SESSION_ID" ]; then
    START_FILE="/tmp/agent-toast-${SESSION_ID}.start"
    if [ -f "$START_FILE" ]; then
        START_TS="$(cat "$START_FILE" 2>/dev/null)"
        if [ -n "$START_TS" ]; then
            ELAPSED=$(( $(date +%s) - START_TS ))
            MINS=$(( ELAPSED / 60 ))
            SECS=$(( ELAPSED % 60 ))
            if [ "$MINS" -gt 0 ]; then
                NOTIFY_DURATION="${MINS}m ${SECS}s"
            else
                NOTIFY_DURATION="${SECS}s"
            fi
        fi
        rm -f "$START_FILE"
    fi
fi

case "$(echo "$BEEP_RAW" | tr '[:upper:]' '[:lower:]')" in
    yes|y|true|1|on) BEEP=1 ;;
    *)               BEEP=0 ;;
esac

detect_os() {
    case "$(uname -s)" in
        Linux*)
            if grep -qi microsoft /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
                echo wsl
            else
                echo linux
            fi
            ;;
        Darwin*) echo macos ;;
        *)       echo unknown ;;
    esac
}
OS="$(detect_os)"

###############################################################################
# Windows / WSL
#
# Uses ToastImageAndText04 (1 image + 3 text fields: title, body1, body2).
# Fake AppId avoids triggering Windows Terminal launch on click.
# Line 1: session label or agent name
# Line 2: project name
# Line 3: duration (filled in later when session-start tracking is wired up)
###############################################################################
notify_wsl() {
    local icon_win icon_uri="" sound_win=""
    if [ -f "$ICON_PATH" ] || [ -f "$(wslpath -u "$ICON_PATH" 2>/dev/null)" ]; then
        if [[ "$ICON_PATH" =~ ^[A-Za-z]: ]]; then
            icon_uri="file:///${ICON_PATH//\\//}"
        else
            icon_win="$(wslpath -w "$ICON_PATH" 2>/dev/null)" || icon_win=""
            [ -n "$icon_win" ] && icon_uri="file:///${icon_win//\\//}"
        fi
    fi
    if [ -f "$SOUND_PATH" ]; then
        sound_win="$(wslpath -w "$SOUND_PATH" 2>/dev/null)" || sound_win=""
    fi

    WSLENV="${WSLENV:-}:ASTRO_TITLE:ASTRO_LINE2:ASTRO_LINE3:ASTRO_ICON_URI:ASTRO_SOUND_WIN:ASTRO_BEEP" \
      ASTRO_TITLE="$NOTIFY_TITLE" \
      ASTRO_LINE2="$PROJECT_NAME" \
      ASTRO_LINE3="$NOTIFY_DURATION" \
      ASTRO_ICON_URI="$icon_uri" \
      ASTRO_SOUND_WIN="$sound_win" \
      ASTRO_BEEP="$BEEP" \
      powershell.exe -NoProfile -Command - <<'PS_EOF' >/dev/null 2>&1 || true
$ErrorActionPreference = 'SilentlyContinue'

# Sound MUST play before any WinRT type loads — loading
# Windows.UI.Notifications.* in this PS process silently breaks
# System.Media.SoundPlayer audio output (verified empirically).
if ($env:ASTRO_BEEP -eq '1' -and $env:ASTRO_SOUND_WIN) {
    (New-Object System.Media.SoundPlayer $env:ASTRO_SOUND_WIN).PlaySync()
}

[void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime]
[void][Windows.Data.Xml.Dom.XmlDocument,                  Windows.Data.Xml.Dom.XmlDocument, ContentType=WindowsRuntime]

# ToastImageAndText04: image + title + 2 body lines. Fake AppId keeps
# notification-only behavior (no WT launch on click).
$tpl = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText04)

if ($env:ASTRO_ICON_URI) {
    $tpl.GetElementsByTagName('image').Item(0).Attributes.GetNamedItem('src').NodeValue = $env:ASTRO_ICON_URI
}

$nodes = $tpl.GetElementsByTagName('text')
[void]$nodes.Item(0).AppendChild($tpl.CreateTextNode($env:ASTRO_TITLE))
[void]$nodes.Item(1).AppendChild($tpl.CreateTextNode($env:ASTRO_LINE2))
[void]$nodes.Item(2).AppendChild($tpl.CreateTextNode($env:ASTRO_LINE3))

$toast = [Windows.UI.Notifications.ToastNotification]::new($tpl)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier([char]0xD83D + [char]0xDD14 + ' Notification').Show($toast)
PS_EOF
}

###############################################################################
# macOS — terminal-notifier with -activate for click-to-focus, or osascript
#
# Detects the running terminal app (iTerm2, Terminal, Warp, Ghostty) and
# passes its bundle ID to terminal-notifier -activate so clicking the
# notification brings the correct terminal window to the foreground.
###############################################################################
notify_macos() {
    local terminal_bundle=""
    if pgrep -x "iTerm2" >/dev/null 2>&1; then
        terminal_bundle="com.googlecode.iterm2"
    elif pgrep -x "WarpTerminal" >/dev/null 2>&1; then
        terminal_bundle="dev.warp.Warp-Stable"
    elif pgrep -x "ghostty" >/dev/null 2>&1; then
        terminal_bundle="com.mitchellh.ghostty"
    elif pgrep -x "Terminal" >/dev/null 2>&1; then
        terminal_bundle="com.apple.Terminal"
    fi

    local msg="Task complete"
    [ -n "$NOTIFY_DURATION" ] && msg="Task complete - ${NOTIFY_DURATION}"

    if command -v terminal-notifier >/dev/null 2>&1; then
        local args=(
            -title    "$NOTIFY_TITLE"
            -subtitle "$PROJECT_NAME"
            -message  "$msg"
            -contentImage "$ICON_PATH"
        )
        [ -n "$terminal_bundle" ] && args+=(-activate "$terminal_bundle")
        terminal-notifier "${args[@]}" >/dev/null 2>&1 || true
    else
        osascript -e "display notification \"$msg\" with title \"$NOTIFY_TITLE\" subtitle \"$PROJECT_NAME\"" \
            >/dev/null 2>&1 || true
    fi

    if [ "$BEEP" -eq 1 ] && [ -f "$SOUND_PATH" ]; then
        afplay "$SOUND_PATH" >/dev/null 2>&1 &
    fi
}

###############################################################################
# Linux — notify-send + audio
###############################################################################
notify_linux() {
    local body="$PROJECT_NAME - Task complete"
    [ -n "$NOTIFY_DURATION" ] && body="$PROJECT_NAME - Task complete (${NOTIFY_DURATION})"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -i "$ICON_PATH" "$NOTIFY_TITLE" "$body" \
            >/dev/null 2>&1 || true
    fi
    if [ "$BEEP" -eq 1 ] && [ -f "$SOUND_PATH" ]; then
        if command -v paplay >/dev/null 2>&1; then
            paplay "$SOUND_PATH" >/dev/null 2>&1 &
        elif command -v aplay >/dev/null 2>&1; then
            aplay -q "$SOUND_PATH" >/dev/null 2>&1 &
        elif command -v play >/dev/null 2>&1; then
            play -q "$SOUND_PATH" >/dev/null 2>&1 &
        fi
    fi
}

case "$OS" in
    wsl)   notify_wsl ;;
    macos) notify_macos ;;
    linux) notify_linux ;;
    *)     exit 0 ;;
esac
exit 0
