# agent-toast

A Claude Code plugin that pops a desktop notification + optional sound whenever Claude finishes a turn (`Stop` event). One shell hook, three platform paths.

## Platforms

| Platform | Notification | Custom icon | Sound | Extra install required? |
|---|---|---|---|---|
| **Windows (via WSL)** | WinRT toast (PowerShell inline, no `.ps1` file → ThreatLocker-safe) | ✅ | `System.Media.SoundPlayer` plays bundled `notify.wav` | None |
| **macOS** | `terminal-notifier` (with icon) **or** `osascript` fallback (no icon) | ✅ with `terminal-notifier`, ❌ without | `afplay notify.wav` | `brew install terminal-notifier` (for icon) |
| **Linux** | `notify-send` (libnotify) | ✅ | `paplay` / `aplay` / `play` — first available | `libnotify-bin` + an audio CLI (most desktop distros ship these) |

If a required tool is missing on a given OS, the hook silently degrades (no notification or no sound) rather than failing.

## Install

```
/plugin marketplace add <git-url-or-local-path>
/plugin install agent-toast@astro-agent-skills
```

Claude Code prompts for three settings; change later via `/plugin config agent-toast`.

## Configuration

| Option | Default | Notes |
|---|---|---|
| Agent name | `Astro Agent` | Toast title |
| Custom icon (PNG only) | *(bundled astronaut)* | Absolute path. Windows-style `C:\path\to\icon.png` or POSIX `/path/to/icon.png`. |
| Play beep after toast? | `no` | Type `yes` to also play `notify.wav` through the audio device |

## macOS prerequisites

For the astronaut icon to show up:

```
brew install terminal-notifier
```

First time the hook fires, macOS may prompt you to **Allow notifications** for the calling app (Script Editor or terminal-notifier). Accept once.

## Linux prerequisites

Most desktop distros have these by default. If missing:

```
# Debian/Ubuntu
sudo apt install libnotify-bin pulseaudio-utils

# Fedora
sudo dnf install libnotify pulseaudio-utils
```

Headless servers (no GUI) will silently skip — there's nowhere to show a notification.

## Implementation notes

- The toast uses the legacy `ToastImageAndText02` template on Windows because the modern `ToastGeneric` template silently drops when the calling AppId isn't a registered AppUserModelID.
- Sound on Windows uses `System.Media.SoundPlayer` (audio device) rather than `[console]::Beep` (motherboard) — the latter is silent under Claude Code's detached hook subprocess because there's no console attached.

## License

MIT — see `LICENSE`.
