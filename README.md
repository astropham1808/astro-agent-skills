# astro-agent-skills

A collection of reusable Codex skills and Claude Code plugins for disciplined,
observable agent-assisted development.

## Codex skills

| Skill | What it does |
|---|---|
| [`disciplined-coding`](./codex/skills/disciplined-coding/) | Guides implementation, refactoring, and review with explicit assumptions, minimal complexity, tightly scoped diffs, and verifiable success criteria. |
| [`project-setup`](./codex/skills/project-setup/) | Classifies, plans, scans, and bootstraps greenfield or existing software products across web, SaaS, desktop, mobile, API, CLI, SDK, developer-tool, data, AI, browser-extension, and hybrid projects. |
| [`codex-multi-agents-flow`](./codex/skills/codex-multi-agents-flow/) | Runs a story through isolated Codex implementation and review sessions, a bounded fix pass, deterministic verification, and a human PR/merge gate. |
| [`close-story-worktree`](./codex/skills/close-story-worktree/) | Verifies that a story PR was merged, then safely removes its exact clean local worktree and merged branch. |

### Install a Codex skill

Ask Codex to use the built-in skill installer with the skill's GitHub path:

```text
Use $skill-installer to install disciplined-coding from
https://github.com/astropham1808/astro-agent-skills/tree/develop/codex/skills/disciplined-coding
```

Replace `disciplined-coding` with `project-setup`, `codex-multi-agents-flow`, or
`close-story-worktree` as needed. Skills install into the Codex skills directory
and are available on the next turn.

## Claude Code plugins

| Plugin | What it does |
|---|---|
| [`agent-toast`](./claude/plugins/agent-toast/) | Sends a cross-platform desktop notification when Claude Code finishes a turn. The Windows path is ThreatLocker-safe and requires no PowerShell modules; macOS and Linux are supported too. |
| [`claude-multi-agent-flow`](./claude/plugins/claude-multi-agent-flow/) | Runs a backlog story end-to-end with Claude Code as builder, Codex CLI as reviewer, and a human merge gate. Includes worktree isolation, spec-first fetch-once, machine-checkable Done-when criteria, and cost-bounded hooks. |

### Install a Claude Code plugin

```text
/plugin marketplace add https://github.com/astropham1808/astro-agent-skills
/plugin install agent-toast@astro-agent-skills
/plugin install claude-multi-agent-flow@astro-agent-skills
```

Pull later changes with `/plugin marketplace update astro-agent-skills`.

`agent-toast` can be configured with an agent name, optional session label,
optional PNG icon path, and optional beep. Reopen its settings with
`/plugin config agent-toast`.

## Repository layout

```text
codex/skills/       Codex skills
claude/plugins/     Claude Code plugins and their bundled skills
.claude-plugin/     Claude Code marketplace catalog
```

Both platforms use `SKILL.md` as the skill contract. Codex skills live under
`codex/skills/<skill>/`; Claude skills belong under
`claude/plugins/<plugin>/skills/<skill>/`.

## Requirements by platform

### macOS

```sh
brew install terminal-notifier
```

`terminal-notifier` enables the custom icon for `agent-toast`. Without it, the
plugin falls back to `osascript` (notifications still work without an icon). The
first hook invocation may prompt for notification permission; allow it once.

### Windows (WSL)

- Windows 10 or 11
- WSL with `wslpath` and `powershell.exe` reachable
- No PowerShell modules required

### Linux

Install the notification and audio utilities if they are missing:

```sh
# Debian/Ubuntu
sudo apt install libnotify-bin pulseaudio-utils

# Fedora
sudo dnf install libnotify pulseaudio-utils
```

On headless servers, `agent-toast` silently skips notifications because there is
no desktop display.

## Local development

```text
/plugin marketplace add /path/to/astro-agent-skills
/plugin install agent-toast@astro-agent-skills
```

Keep each skill self-contained: update its `SKILL.md`, scripts, assets, and
references together, then verify any affected shell scripts on the target
platform before publishing.
