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
| [disciplined-coding](../codex/skills/disciplined-coding/) | Codex | Foundation | Cross-stack | No framework requirement; examples are implementation-neutral. | Keep as the default quality/practice skill. |
| [project-setup](../codex/skills/project-setup/) | Codex | Planning and setup | Cross-stack, repository-aware | Product-type guidance is broad; stack is intentionally discovered rather than assumed. | Keep. |
| [codex-multi-agents-flow](../codex/skills/codex-multi-agents-flow/) | Codex | Delivery orchestration | Codex-native + Git worktree | Provider and worktree mechanics are intentional; project verification and generic fallback remain stack-neutral. | Keep as a Codex adapter; verify its stage and failure gates hermetically. |
| [close-story-worktree](../codex/skills/close-story-worktree/) | Codex | Repository lifecycle | GitHub CLI/Git-specific | gh, PR merge state, worktrees, and local branches are the contract. | Keep; do not generalize into a generic coding skill. |
| [godmode-dev-flow](../claude/plugins/godmode-dev-flow/) | Claude Code | Delivery orchestration | Claude + Codex + Git worktree | Distribution bundle, not a skill. Carries the four story lifecycle skills below so one install covers setup through cleanup. | Keep as the single namespace for Claude story skills; add new lifecycle skills here rather than as new plugins. |
| [agent-toast](../claude/plugins/agent-toast/) | Claude Code | Platform integration | Claude hooks + Windows/macOS/Linux | OS notification commands and Claude hook variables are required by the feature. | Keep as a separate plugin; it ships no skills and owns its own userConfig. Use mocked OS commands in CI and live OS canaries before release. |
| [start-story-multi-agent](../claude/plugins/godmode-dev-flow/skills/start-story-multi-agent/) | Claude Code | Delivery orchestration | Claude + Codex + Git worktree | Provider mechanics are intentional. Base branch, source-of-truth query, verifier, and formatter are project-configured. | Keep as the Claude adapter; verify installed paths, stage gates, and human PR ownership hermetically. |
| [project-setup](../claude/plugins/godmode-dev-flow/skills/project-setup/) | Claude Code | Planning and setup | Cross-stack, repository-aware | Port of the Codex skill. Shares its scripts, assets, and references byte for byte; only SKILL.md and the plugin manifest differ. | Keep in sync with the Codex skill; the shared payload is the single source of truth. |
| [close-story](../claude/plugins/godmode-dev-flow/skills/close-story/) | Claude Code | Repository lifecycle | GitHub CLI/Git-specific | Port of the Codex close-story-worktree skill, sharing the same cleanup script. Branch naming stays convention-agnostic across codex/, worktree-, and claude/ prefixes. | Keep; do not generalize into a generic coding skill. |
| [disciplined-coding](../claude/plugins/godmode-dev-flow/skills/disciplined-coding/) | Claude Code | Foundation | Cross-stack | Port of the Codex skill. Prose only, no scripts or assets. | Keep as the default quality/practice skill on both platforms. |

## Coupling decisions

### Intentional specialization

- The Codex and Claude flow skills are separate because they automate different
  provider CLIs and sandbox/review mechanics.
- project-setup, close-story-worktree, and disciplined-coding ship on both
  platforms. Their contract is provider-neutral, so the port duplicates only
  SKILL.md and the manifest; scripts, assets, and references stay byte-identical
  and are verified by `diff -r`.
- Codex distributes one skill per installer path, so `codex/skills/<skill>/` is
  flat. Claude Code distributes only through plugins, and invokes a bundled skill
  as `plugin:skill`. One plugin per skill therefore produced names like
  `close-story-worktree:close-story-worktree`. The four Claude story skills are
  bundled under `godmode-dev-flow` so the namespace carries meaning and one
  install covers the whole lifecycle. This rename is the exception allowed by
  principle 5: the duplicated call name was the defect being fixed.
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
- The Claude story flow no longer requires main or Notion. It resolves a base branch
  and accepts either a completed local spec or a configured narrow remote query.
- Story bootstrapping no longer checks out or pulls the primary worktree, and both
  delivery flows stop before creating a pull request.
- The Claude flow skill no longer presents provider performance claims as a general
  rule. Builder/reviewer roles are selected by scope, verification, and available
  tooling.

## Change policy

When adding or changing a skill, record its trigger and exclusions, platform,
category, portability, required external interfaces, configurable inputs, external
side effects, failure behavior, and whether any stack coupling is intentional. A
new framework-specific skill belongs in Platform integration only when the framework
is the actual contract; otherwise keep the core workflow generic and isolate the
framework in an adapter or example.

## Verification

Classification changes are complete when:

- every SKILL.md and plugin is represented in the matrix;
- README tables, plugin manifests, and marketplace metadata agree with this file;
- stack-specific commands appear only in project-owned configuration or clearly
  labeled examples;
- JSON parses, changed shell files pass bash -n, links resolve locally, and
  git diff --check passes;
- bundled paths resolve from an installed skill or plugin rather than the project
  working directory;
- hermetic tests cover happy paths and failure gates without calling real agents,
  issue trackers, notification services, GitHub mutations, or paid APIs;
- a live canary covers each advertised runtime or operating-system integration
  before publishing a release.
