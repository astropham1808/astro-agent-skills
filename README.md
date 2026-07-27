# astro-agent-skills

A collection of reusable Codex skills and Claude Code plugins.

## Codex skills

| Skill | What it does |
|---|---|
| [`close-story-worktree`](./codex/skills/close-story-worktree/) | Verifies that a story PR was merged, then safely removes its clean local worktree and merged branch. |
| [`project-setup`](./codex/skills/project-setup/) | Classifies, plans, scans, and bootstraps greenfield or existing software products. Supports web, SaaS, desktop, mobile, API, CLI, SDK, developer-tool, data, AI, browser-extension, and hybrid projects. |

### Install a Codex skill

Ask Codex:

```text
Use $skill-installer to install project-setup from
https://github.com/astropham1808/astro-agent-skills/tree/develop/codex/skills/project-setup
```

## Claude Code plugins

| Plugin | What it does |
|---|---|
| [`agent-toast`](./claude/plugins/agent-toast/) | Desktop notification when Claude finishes a turn. Built for WSL users in restricted environments where Claude Desktop is blocked by policy or endpoint security (ThreatLocker-safe: no `.ps1` file, no modules). Also works on macOS and Linux. |
| [`claude-multi-agent-flow`](./claude/plugins/claude-multi-agent-flow/) | Runs backlog stories in parallel, one git worktree ("berth") per story. Claude Code builds, Codex CLI reviews read-only, a human merges. Ships berth bootstrap, spec-first fetch-once, risk-routed review, exclusive-resource locks, a WIP cap, a serialised landing queue, and a board derived from git rather than from agent self-reports. Every project-specific value lives in one `.agentflow.conf`. |

### Install a Claude Code plugin

```
/plugin marketplace add https://github.com/astropham1808/astro-agent-skills
/plugin install agent-toast@astro-agent-skills
/plugin install claude-multi-agent-flow@astro-agent-skills
```

Pull later changes with `/plugin marketplace update astro-agent-skills`.

After install, Claude Code prompts for three settings (agent name / icon path / beep on/off). Reopen the form anytime via `/plugin config agent-toast`.

## Repository layout

```text
codex/skills/       Codex skills
claude/plugins/     Claude Code plugins and their bundled skills
.claude-plugin/     Claude Code marketplace catalog
```

Codex and Claude can both use `SKILL.md`, so the platform directory is the
authoritative signal. A Claude skill belongs under
`claude/plugins/<plugin>/skills/<skill>/`.

## Requirements by platform

### macOS

```
brew install terminal-notifier
```

`terminal-notifier` enables the custom icon. Without it the plugin falls back to `osascript` (notification works, no icon). The first time the hook fires, macOS may prompt you to allow notifications. Accept once.

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

Headless servers (no GUI) silently skip because there is nowhere to display a notification.

## Local development

```
/plugin marketplace add /path/to/astro-agent-skills
/plugin install agent-toast@astro-agent-skills
```
