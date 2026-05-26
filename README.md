# astro-agent-skills

A small Claude Code plugin marketplace. Currently ships one plugin; more may follow.

## Plugins in this marketplace

| Plugin | What it does |
|---|---|
| [`agent-toast`](./plugins/agent-toast/) | Pops a Windows toast (no PowerShell module, ThreatLocker-safe) when Claude finishes a turn. Configurable agent name, icon, optional beep. |

## Install

```
/plugin marketplace add <git-url-or-local-path>
/plugin install agent-toast@astro-agent-skills
```

For local testing while developing:

```
/plugin marketplace add /mnt/d/astro-agent-skills
/plugin install agent-toast@astro-agent-skills
```

After install, Claude Code prompts for the plugin's three settings (agent name / icon path / beep on/off). Re-open the form anytime via `/plugin config agent-toast`.

## Requirements

- Windows 10 or 11 (toast renders via WinRT)
- WSL with `wslpath` and `powershell.exe` reachable
- No PowerShell modules needed
