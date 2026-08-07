# Skill taxonomy

This document is the classification contract for the repository's Codex skills and
Claude Code plugins. It separates a skill's primary problem from the platform or
integration it uses to solve that problem.

## Classification principles

1. Classify by the primary contract and user outcome, not by the language or
   framework used in an example.
2. Keep provider and operating-system boundaries visible when they are required by
   the runtime. Do not pretend a Claude hook or a GitHub cleanup command is
   cross-platform.
3. Treat stack examples as configuration guidance, not as a hidden requirement.
4. Prefer a reusable core plus an explicit adapter when a workflow has both generic
   rules and provider-specific mechanics.
5. Preserve existing install paths unless a rename is necessary; documentation and
   metadata changes should be backwards-compatible.

## Categories

| Category | Primary contract | Typical portability |
| --- | --- | --- |
| Foundation | Improve how an agent reasons, edits, and verifies work. | Cross-stack |
| Planning and setup | Classify a product or repository and create its delivery foundation. | Cross-stack, repository-aware |
| Delivery orchestration | Coordinate implementation, review, verification, and human gates. | Agent/provider-specific mechanics around a stack-neutral workflow |
| Repository lifecycle | Safely create, review, close, or clean up Git work. | Git/GitHub-specific |
| Platform integration | Connect an agent to an OS, hook, notification surface, or external runtime. | Platform-specific by design |

## Current classification

| Artifact | Platform | Category | Portability | Coupling assessment | Decision |
| --- | --- | --- | --- | --- | --- |
| disciplined-coding (../codex/skills/disciplined-coding/) | Codex | Foundation | Cross-stack | No framework requirement; examples are implementation-neutral. | Keep as the default quality/practice skill. |
| project-setup (../codex/skills/project-setup/) | Codex | Planning and setup | Cross-stack, repository-aware | Product-type guidance is broad; stack is intentionally discovered rather than assumed. | Keep. |
| codex-multi-agents-flow (../codex/skills/codex-multi-agents-flow/) | Codex | Delivery orchestration | Codex-native + Git worktree | Provider and worktree mechanics are intentional; verifier fallback is stack-neutral. | Keep as a Codex adapter. |
| close-story-worktree (../codex/skills/close-story-worktree/) | Codex | Repository lifecycle | GitHub CLI/Git-specific | gh, PR merge state, worktrees, and local branches are the contract. | Keep; do not generalize into a generic coding skill. |
| claude-multi-agent-flow (../claude/plugins/claude-multi-agent-flow/) | Claude Code | Delivery orchestration | Claude + Codex adapter | Provider boundary is intentional. Rust/Node/Playwright defaults were accidental coupling and are now project-configured. | Keep as a Claude adapter; use project-owned verification and formatting hooks. |
| agent-toast (../claude/plugins/agent-toast/) | Claude Code | Platform integration | Claude hooks + Windows/macOS/Linux | OS notification commands and Claude hook variables are required by the feature. | Keep as an explicit integration; marketplace category is integration. |

## Coupling decisions

### Intentional specialization

- The Codex and Claude flow skills are separate because they automate different
  provider CLIs and sandbox/review mechanics.
- close-story-worktree is intentionally tied to GitHub PR state and Git worktrees.
- agent-toast is intentionally tied to Claude lifecycle hooks and desktop
  notification APIs.

### Removed accidental specialization

- Claude story specs no longer prescribe Rust, Playwright, or a particular test
  command; each project supplies its own executable acceptance checks.
- The Claude flow verifier and pre-commit template no longer run a fixed Rust/Node matrix. They delegate to
  the target project's scripts/verify-project.sh.
- The Claude PostToolUse formatter hook no longer assumes rustfmt or Prettier. A
  target project may provide scripts/format-file.sh; otherwise the hook is a safe
  no-op.
- The Claude flow skill no longer presents provider performance claims as a general
  rule. Builder/reviewer roles are selected by scope, verification, and available
  tooling.

## Change policy

When adding a skill, record its platform, category, portability, required external
interfaces, and whether any stack coupling is intentional. A new framework-specific
skill belongs in Platform integration only when the framework is the actual
contract; otherwise keep the core workflow generic and isolate the framework in an
adapter or example.

## Verification

Classification changes are complete when:

- every SKILL.md and plugin is represented in the matrix;
- README tables, plugin manifests, and marketplace metadata agree with this file;
- stack-specific commands appear only in project-owned configuration or clearly
  labeled examples;
- JSON parses, changed shell files pass bash -n, links resolve locally, and
  git diff --check passes.
