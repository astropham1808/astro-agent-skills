# astro-agent-skills

A collection of reusable Codex skills and Claude Code plugins for disciplined,
observable agent-assisted development. The skills are classified by their primary
contract and documented in docs/SKILL_TAXONOMY.md.

## Codex skills

| Category | Skill | Scope |
|---|---|---|
| Foundation | [disciplined-coding](./codex/skills/disciplined-coding/) | Cross-stack coding quality, scope control, and verification. |
| Planning and setup | [project-setup](./codex/skills/project-setup/) | Cross-stack product and repository planning. |
| Delivery orchestration | [codex-multi-agents-flow](./codex/skills/codex-multi-agents-flow/) | Codex-native implement/review/verify flow. |
| Repository lifecycle | [close-story-worktree](./codex/skills/close-story-worktree/) | GitHub PR and Git worktree cleanup. |

### Install a Codex skill

Ask Codex to use the built-in skill installer with the skill's GitHub path:

~~~text
Use $skill-installer to install disciplined-coding from
https://github.com/astropham1808/astro-agent-skills/tree/develop/codex/skills/disciplined-coding
~~~

Replace disciplined-coding with project-setup, codex-multi-agents-flow, or
close-story-worktree as needed. Skills install into the Codex skills directory
and are available on the next turn.

## Claude Code plugins

| Category | Plugin | Scope |
|---|---|---|
| Platform integration | [agent-toast](./claude/plugins/agent-toast/) | Claude lifecycle notifications on Windows/WSL, macOS, and Linux. |
| Delivery orchestration | [claude-multi-agent-flow](./claude/plugins/claude-multi-agent-flow/) | Claude implementer + read-only Codex reviewer with configurable source, base branch, and project verification. |

### Install a Claude Code plugin

~~~text
/plugin marketplace add https://github.com/astropham1808/astro-agent-skills
/plugin install agent-toast@astro-agent-skills
/plugin install claude-multi-agent-flow@astro-agent-skills
~~~

Pull later changes with /plugin marketplace update astro-agent-skills, then update
the installed plugin with /plugin update <plugin>@astro-agent-skills.

agent-toast can be configured with an agent name, optional session label,
optional PNG icon path, and optional beep. Reopen its settings with
/plugin config agent-toast.

The Claude multi-agent flow keeps its provider-specific mechanics, but its story
template, verifier, and formatter hook are stack-neutral. Projects provide their
own executable scripts/verify-project.sh and optional scripts/format-file.sh.

## Repository layout

~~~text
codex/skills/       Codex skills
claude/plugins/     Claude Code plugins and their bundled skills
.claude-plugin/     Claude Code marketplace catalog
docs/               Taxonomy and repository documentation
tests/              Hermetic contract and failure-gate tests
.github/workflows/  Automated verification
~~~

Both platforms use SKILL.md as the skill contract. Codex skills live under
codex/skills/<skill>/; Claude skills belong under
claude/plugins/<plugin>/skills/<skill>/.

See docs/SKILL_TAXONOMY.md before adding a new skill or deciding whether a
framework-specific workflow should be a core skill or an adapter.

## Requirements by platform

### macOS

~~~sh
brew install terminal-notifier
~~~

terminal-notifier enables the custom icon for agent-toast. Without it, the plugin
falls back to osascript (notifications still work without an icon). The first hook
invocation may prompt for notification permission; allow it once.

### Windows (WSL)

- Windows 10 or 11
- WSL with wslpath and powershell.exe reachable
- No PowerShell modules required

### Linux

Install the notification and audio utilities if they are missing:

~~~sh
# Debian/Ubuntu
sudo apt install libnotify-bin pulseaudio-utils

# Fedora
sudo dnf install libnotify pulseaudio-utils
~~~

On headless servers, agent-toast silently skips notifications because there is no
desktop display.

## Local development

~~~bash
python tests/test_skill_contracts.py
claude plugin validate . --strict
~~~

Keep each skill self-contained: update its SKILL.md, scripts, assets, and references
together. The test suite uses temporary Git repositories and mocked Claude, Codex,
GitHub, and notification commands, so it does not call paid APIs or mutate external
systems. Run shell behavior tests under WSL or POSIX, then run one live canary on
every advertised provider or operating-system integration before publishing.
