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
ICON_PATH="${CLAUDE_PLUGIN_OPTION_ICON_PATH:-}"
BEEP_RAW="${CLAUDE_PLUGIN_OPTION_BEEP_ENABLED:-no}"

if [ -z "$ICON_PATH" ]; then
    ICON_PATH="${CLAUDE_PLUGIN_ROOT}/assets/default-icon.png"
fi

SOUND_PATH="${CLAUDE_PLUGIN_ROOT}/assets/notify.wav"
PROJECT_NAME="$(basename "$PWD")"

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
# Uses Microsoft.WindowsTerminal_8wekyb3d8bbwe!App as the AppUserModelId so
# clicking the toast brings the correct Windows Terminal window to the
# foreground. Windows handles window selection automatically: when there is
# one WT window it focuses it directly; when there are multiple it shows the
# taskbar thumbnail picker. ToastGeneric is used because a real registered
# AppId is now available, giving richer layout and a proper logo override.
# Falls back to the legacy ToastImageAndText02 approach if WT is not found.
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

    WSLENV="${WSLENV:-}:ASTRO_AGENT_NAME:ASTRO_PROJECT_NAME:ASTRO_ICON_URI:ASTRO_SOUND_WIN:ASTRO_BEEP" \
      ASTRO_AGENT_NAME="$AGENT_NAME" \
      ASTRO_PROJECT_NAME="$PROJECT_NAME" \
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

$title  = $env:ASTRO_AGENT_NAME
$body   = if ($env:ASTRO_PROJECT_NAME) { "$($env:ASTRO_PROJECT_NAME) - Task complete" } else { 'Task complete' }
$iconXml = if ($env:ASTRO_ICON_URI) {
    "<image placement=""appLogoOverride"" src=""$($env:ASTRO_ICON_URI)"" hint-crop=""circle""/>"
} else { '' }

# Windows Terminal AppUserModelId — clicking the toast activates WT directly,
# focusing the window that generated the notification.
$wtAppId = 'Microsoft.WindowsTerminal_8wekyb3d8bbwe!App'
$notifier = $null
$useGeneric = $false
try {
    $notifier  = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($wtAppId)
    $useGeneric = $true
} catch {
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier(
        [char]0xD83D + [char]0xDD14 + ' Notification')
}

if ($useGeneric) {
    $xml = "<toast><visual><binding template=""ToastGeneric""><text>$title</text><text>$body</text>$iconXml</binding></visual></toast>"
    $doc = [Windows.Data.Xml.Dom.XmlDocument]::new()
    try {
        $doc.LoadXml($xml)
        $notifier.Show([Windows.UI.Notifications.ToastNotification]::new($doc))
    } catch {
        $useGeneric = $false
    }
}

if (-not $useGeneric) {
    # Legacy fallback: ToastImageAndText02 works with any AppId.
    $tpl = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(
        [Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText02)
    if ($env:ASTRO_ICON_URI) {
        $tpl.GetElementsByTagName('image').Item(0).Attributes.GetNamedItem('src').NodeValue = $env:ASTRO_ICON_URI
    }
    $nodes = $tpl.GetElementsByTagName('text')
    [void]$nodes.Item(0).AppendChild($tpl.CreateTextNode($title))
    [void]$nodes.Item(1).AppendChild($tpl.CreateTextNode($body))
    $notifier.Show([Windows.UI.Notifications.ToastNotification]::new($tpl))
}
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

    if command -v terminal-notifier >/dev/null 2>&1; then
        local args=(
            -title  "$AGENT_NAME"
            -subtitle "$PROJECT_NAME"
            -message "Task complete"
            -contentImage "$ICON_PATH"
        )
        [ -n "$terminal_bundle" ] && args+=(-activate "$terminal_bundle")
        terminal-notifier "${args[@]}" >/dev/null 2>&1 || true
    else
        osascript -e "display notification \"Task complete\" with title \"$AGENT_NAME\" subtitle \"$PROJECT_NAME\"" \
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
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -i "$ICON_PATH" "$AGENT_NAME" "$PROJECT_NAME - Task complete" \
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
