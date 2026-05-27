#!/usr/bin/env bash
# agent-toast — Stop hook (cross-platform: Windows/WSL, macOS, Linux)
#
# Reads three values that Claude Code populates from the plugin's userConfig:
#   CLAUDE_PLUGIN_OPTION_AGENT_NAME    -- toast title
#   CLAUDE_PLUGIN_OPTION_ICON_PATH     -- absolute PNG path (blank = bundled icon)
#   CLAUDE_PLUGIN_OPTION_BEEP_ENABLED  -- "yes"/"y"/"true"/"1"/"on" (anything else = silent)
#
# CLAUDE_PLUGIN_ROOT points at this plugin's install directory.

set -u

AGENT_NAME="${CLAUDE_PLUGIN_OPTION_AGENT_NAME:-Agent}"
ICON_PATH="${CLAUDE_PLUGIN_OPTION_ICON_PATH:-}"
BEEP_RAW="${CLAUDE_PLUGIN_OPTION_BEEP_ENABLED:-no}"

# Default icon = bundled astronaut when user left field blank.
if [ -z "$ICON_PATH" ]; then
    ICON_PATH="${CLAUDE_PLUGIN_ROOT}/assets/default-icon.png"
fi

SOUND_PATH="${CLAUDE_PLUGIN_ROOT}/assets/notify.wav"

# Normalise beep flag → "1" or "0".
case "$(echo "$BEEP_RAW" | tr '[:upper:]' '[:lower:]')" in
    yes|y|true|1|on) BEEP=1 ;;
    *)               BEEP=0 ;;
esac

# Detect OS: wsl (Windows via WSL) | macos | linux | unknown.
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
# Windows / WSL — powershell.exe + WinRT toast + SoundPlayer
###############################################################################
notify_wsl() {
    # Translate Linux/WSL paths to Windows file:// URI for the toast XML.
    local icon_win icon_uri="" sound_win sound_uri=""
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

    WSLENV="${WSLENV:-}:ASTRO_AGENT_NAME:ASTRO_ICON_URI:ASTRO_SOUND_WIN:ASTRO_BEEP" \
      ASTRO_AGENT_NAME="$AGENT_NAME" \
      ASTRO_ICON_URI="$icon_uri" \
      ASTRO_SOUND_WIN="$sound_win" \
      ASTRO_BEEP="$BEEP" \
      powershell.exe -NoProfile -Command - <<'PS_EOF' >/dev/null 2>&1 || true
$ErrorActionPreference = 'SilentlyContinue'

# Sound MUST play before any WinRT type loads — loading
# Windows.UI.Notifications.* in this PS process silently breaks
# System.Media.SoundPlayer audio output (verified empirically).
# PlaySync (not Play) — Play is async and the PS process exits
# before the sound thread can run when invoked from a detached
# hook subprocess.
if ($env:ASTRO_BEEP -eq '1' -and $env:ASTRO_SOUND_WIN) {
    (New-Object System.Media.SoundPlayer $env:ASTRO_SOUND_WIN).PlaySync()
}

[void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime]
[void][Windows.Data.Xml.Dom.XmlDocument,                  Windows.Data.Xml.Dom.XmlDocument, ContentType=WindowsRuntime]

# Legacy ToastImageAndText02 — renders with any AppId; ToastGeneric silently
# drops without a registered AppUserModelID.
$tpl = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(
    [Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText02)

if ($env:ASTRO_ICON_URI) {
    $tpl.GetElementsByTagName('image').Item(0).Attributes.GetNamedItem('src').NodeValue = $env:ASTRO_ICON_URI
}

$nodes = $tpl.GetElementsByTagName('text')
[void]$nodes.Item(0).AppendChild($tpl.CreateTextNode(($env:ASTRO_AGENT_NAME)))
[void]$nodes.Item(1).AppendChild($tpl.CreateTextNode('Task complete'))

$toast = [Windows.UI.Notifications.ToastNotification]::new($tpl)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier([char]0xD83D + [char]0xDD14 + ' Notification').Show($toast)
PS_EOF
}

###############################################################################
# macOS — terminal-notifier (for icon) or osascript fallback + afplay
###############################################################################
notify_macos() {
    if command -v terminal-notifier >/dev/null 2>&1; then
        # -appIcon is ignored on macOS 10.9+; -contentImage shows the image in the notification body.
        terminal-notifier \
            -title "$AGENT_NAME" \
            -message "Task complete" \
            -contentImage "$ICON_PATH" \
            >/dev/null 2>&1 || true
    else
        # Fallback: osascript display notification (no custom icon possible).
        osascript -e "display notification \"Task complete\" with title \"$AGENT_NAME\"" \
            >/dev/null 2>&1 || true
    fi
    if [ "$BEEP" -eq 1 ] && [ -f "$SOUND_PATH" ]; then
        afplay "$SOUND_PATH" >/dev/null 2>&1 &
    fi
}

###############################################################################
# Linux — notify-send + (paplay | aplay | play)
###############################################################################
notify_linux() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -i "$ICON_PATH" "$AGENT_NAME" "Task complete" \
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
