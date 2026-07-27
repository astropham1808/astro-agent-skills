# astro-agent-skills

A collection of reusable Codex skills and Claude Code plugins.

## Codex skills

| Skill | What it does |
|---|---|
| [`project-setup`](./skills/project-setup/) | Classifies, plans, scans, and bootstraps greenfield or existing software products. Supports web, SaaS, desktop, mobile, API, CLI, SDK, developer-tool, data, AI, browser-extension, and hybrid projects. |

### Install a Codex skill

Ask Codex:

```text
Use $skill-installer to install project-setup from
https://github.com/astropham1808/astro-agent-skills/tree/develop/skills/project-setup
```

## Claude Code plugins

| Plugin | What it does |
|---|---|
| [`agent-toast`](./plugins/agent-toast/) | Desktop notification when Claude finishes a turn. Built for WSL users in restricted environments where Claude Desktop is blocked by policy or endpoint security (ThreatLocker-safe: no `.ps1` file, no modules). Also works on macOS and Linux. |

### Install a Claude Code plugin

```
/plugin marketplace add https://github.com/astropham1808/astro-agent-skills
/plugin install agent-toast@astro-agent-skills
```

After install, Claude Code prompts for three settings (agent name / icon path / beep on/off). Re-open the form anytime via `/plugin config agent-toast`.

## Requirements by platform

### macOS

```
brew install terminal-notifier
```

`terminal-notifier` enables the custom icon. Without it the plugin falls back to `osascript` (notification works, no icon). First time the hook fires, macOS may prompt you to allow notifications — accept once.

### Windows (WSL)

- Windows 10 or 11
- WSL with `wslpath` and `powershell.exe` reachable
- No PowerShell modules needed

### Linux

Most desktop distros include these by default. Install if missing:

```bash
# Debian/Ubuntu
sudo apt install libnotify-bin pulseaudio-utils

# Fedora
sudo dnf install libnotify pulseaudio-utils
```

Headless servers (no GUI) silently skip — there is nowhere to display a notification.

## Local development

```
/plugin marketplace add /path/to/astro-agent-skills
/plugin install agent-toast@astro-agent-skills
```
