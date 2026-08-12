# astro-agent-skills

Agent skills that make one story go from a request to a reviewed branch without
anyone pretending the work is done. Claude Code implements, Codex CLI reviews in
a read-only sandbox, an executable verifier decides what "done" means, and a
human owns the pull request and the merge.

Ships as Codex skills and as a Claude Code plugin marketplace. No stack lock-in,
no provider lock-in, no hidden framework assumptions.

## Why this exists

Agent-assisted delivery breaks in the same few places every time.

The agent says the work is complete when nothing ran. The reviewer is the same
session that wrote the code, so it agrees with itself. A refactor wanders into
files nobody asked about. The agent pushes, opens a PR, or merges while you are
still reading the diff. Two agents edit the same working tree and one of them
loses.

These skills close each of those holes with a mechanism rather than a
suggestion: verification is an exit code, review runs in a separate read-only
session, each story gets its own Git worktree, and every external or destructive
action stops at a human gate.

## What it gives you

Four skills covering the story lifecycle, plus a notification plugin.

| Category | Skill | What it owns |
|---|---|---|
| Planning and setup | project-setup | Classify the product, plan the repo, scaffold the verification contract. |
| Foundation | disciplined-coding | Scoped diffs, stated assumptions, verifiable success criteria. |
| Delivery orchestration | start-story-multi-agent, codex-multi-agents-flow | One story: implement, verify, independent review, one bounded fix pass. |
| Repository lifecycle | close-story, close-story-worktree | Tear down the worktree and branch after the merge, never before. |
| Platform integration | agent-toast | Desktop notification when Claude finishes. Hooks only, no skills. |

Every Codex skill has a Claude Code counterpart. The two delivery-orchestration
skills stay separate because they automate different provider CLIs. The other
three are ports that share their scripts, assets, and references byte for byte
with the Codex originals, which the test suite enforces.

Claude invokes a bundled skill as `plugin:skill`:

| Skill | Call | Source |
|---|---|---|
| project-setup | `godmode-dev-flow:project-setup` | [Claude](./claude/plugins/godmode-dev-flow/skills/project-setup/), [Codex](./codex/skills/project-setup/) |
| disciplined-coding | `godmode-dev-flow:disciplined-coding` | [Claude](./claude/plugins/godmode-dev-flow/skills/disciplined-coding/), [Codex](./codex/skills/disciplined-coding/) |
| start-story-multi-agent | `godmode-dev-flow:start-story-multi-agent` | [Claude](./claude/plugins/godmode-dev-flow/skills/start-story-multi-agent/) |
| close-story | `godmode-dev-flow:close-story` | [Claude](./claude/plugins/godmode-dev-flow/skills/close-story/), [Codex](./codex/skills/close-story-worktree/) |
| codex-multi-agents-flow | Codex only | [Codex](./codex/skills/codex-multi-agents-flow/) |

## Install

### Claude Code

~~~text
/plugin marketplace add https://github.com/astropham1808/astro-agent-skills
/plugin install godmode-dev-flow@astro-agent-skills
/plugin install agent-toast@astro-agent-skills
~~~

Pull later changes with `/plugin marketplace update astro-agent-skills`, then
`/plugin update <plugin>@astro-agent-skills`.

Upgrading from the pre-2.0 catalog: the four separate story plugins were merged
into godmode-dev-flow. Uninstall the old ones first, since the plugin name is the
install key.

~~~text
/plugin uninstall claude-multi-agent-flow@astro-agent-skills
/plugin uninstall close-story-worktree@astro-agent-skills
/plugin uninstall disciplined-coding@astro-agent-skills
/plugin uninstall project-setup@astro-agent-skills
~~~

### Codex

Ask Codex to use the built-in skill installer with the skill's GitHub path:

~~~text
Use $skill-installer to install disciplined-coding from
https://github.com/astropham1808/astro-agent-skills/tree/develop/codex/skills/disciplined-coding
~~~

Replace `disciplined-coding` with `project-setup`, `codex-multi-agents-flow`, or
`close-story-worktree`. Skills install into the Codex skills directory and are
available on the next turn.

### Editable install

~~~bash
git clone https://github.com/astropham1808/astro-agent-skills
/plugin marketplace add ./astro-agent-skills
~~~

* * *

## Quickstart

Your repository needs exactly one thing these skills do not ship: a command that
decides whether the work is good. Everything else is generated.

**You:** `set up this repo for the story flow`

**Agent:** runs project-setup, classifies the product, writes the plan, backlog,
engineering guide, and repository instructions, then scaffolds the verifier:

~~~bash
# preview what would be generated, change nothing
"${CLAUDE_SKILL_DIR}/scripts/init-verifier.sh" --print

# write scripts/verify-project.sh and mark it executable
"${CLAUDE_SKILL_DIR}/scripts/init-verifier.sh"
~~~

The scaffold reads the repository's own stack markers and writes the matching
lint, typecheck, test, and build commands. It never overwrites an existing
verifier without `--force`. When it recognizes no stack it writes a `TODO`
verifier that exits non-zero, so an unconfigured project fails loudly instead of
reporting a fake pass. Use `--root <path>` to scaffold a repository other than
the current directory.

Review the generated commands and run it once:

~~~bash
scripts/verify-project.sh
~~~

**You:** `start story AL-161`

**Agent:** opens an isolated worktree, writes the spec, implements, verifies,
hands the branch to Codex for an independent read-only review, applies at most
one fix pass, verifies again, and stops with a suggested `gh pr create`.

**You:** read the diff, push, open the PR, merge.

**You:** `PR merged rồi, dọn worktree`

**Agent:** runs close-story, confirms `mergedAt` on the exact PR, requires a
clean worktree, previews the cleanup, then removes the worktree and deletes the
local branch.

## The flow

~~~text
project-setup ──► specs/<ID>.md ──► new-story.sh ──► story.sh ──┐
                                                                │
   ┌────────────────────────────────────────────────────────────┘
   │
   ├─ 1  implement and commit          (Claude, or Codex in the Codex flow)
   ├─ 2  verify                        (exit code decides, not prose)
   ├─ 3  review                        (separate session, read-only sandbox)
   ├─ 4  one fix pass, at most         (skipped on VERDICT: PASS)
   ├─ 5  verify and re-review          (only when a fix ran)
   └─ 6  stop  ────────────────────►   HUMAN: push, PR, merge
                                                │
                                                ▼
                                          close-story
~~~

A failed stage stops every later stage. Traces from every agent run land in the
worktree's ignored `.claude-flow/<ID>/` or `.codex-flow/<ID>/`.

### Running it by hand

~~~bash
"${CLAUDE_SKILL_DIR}/scripts/new-story.sh" AL-161            # base from origin/HEAD
"${CLAUDE_SKILL_DIR}/scripts/new-story.sh" AL-161 trunk      # explicit base
# complete .claude/worktrees/AL-161/specs/AL-161.md
"${CLAUDE_SKILL_DIR}/scripts/story.sh" AL-161
~~~

With a remote source of truth instead of a hand-written spec:

~~~bash
SOT_QUERY='<one narrow Notion query, Jira JQL, or issue URL>' \
  "${CLAUDE_SKILL_DIR}/scripts/story.sh" AL-161
~~~

The story ID must match `PREFIX-nnn`. The scripts reject any other shape.

## What runs when

Skills load from what you say, so these are the phrases that reach for each one.

| You say | What loads | What it does |
|---|---|---|
| "plan trước khi code", "set up project", "bootstrap repo" | project-setup | Classifies, plans, and bootstraps before any implementation code. |
| "keep the diff small", "don't overengineer", "chỉ sửa đúng chỗ" | disciplined-coding | Scopes the diff, states assumptions, defines checkable success. |
| "start story AL-161", "hand this to Codex to review" | start-story-multi-agent | Runs the full two-agent pipeline for one story. |
| "PR merged rồi", "dọn worktree", "clean up the branch" | close-story | Verifies the merge, then removes the worktree and branch. |
| nothing, it is a hook | agent-toast | Notifies your desktop when Claude stops. |

## How verification resolves

Both delivery flows share one `scripts/verify.sh`. It resolves the definition of
done in a fixed order:

1. `PROJECT_VERIFIER`, absolute or relative to the repository root, for projects
   that already keep their checks somewhere else.
2. `scripts/verify-project.sh`, the preferred project-owned verifier.
3. Generic checks detected from `Cargo.toml`, `package.json` with its lockfile's
   package manager, `go.mod`, `pom.xml` or a Gradle build, `pyproject.toml`, or a
   .NET project file.

A repository with no recognizable stack and no verifier stops with exit 2 rather
than passing by default. A verifier that exists but lost its executable bit, a
common result of a Windows checkout, also stops, with a `chmod +x` hint instead
of being silently skipped. JVM projects prefer the repository's own `./mvnw` or
`./gradlew` over a globally installed tool, so the build stays pinned.

The same contract backs the `pre-commit` hook, so a commit cannot pass what the
flow would fail.

## Requirements

The scripts check their own dependencies and exit 2 with the missing command
name.

| Stage | Required on PATH |
|---|---|
| new-story.sh (both flows) | git, mkdir, cp, grep, sed, rm |
| start-story-multi-agent story.sh | claude, codex, git, tee, jq, grep, mkdir |
| codex-multi-agents-flow story.sh | codex, git, tee, grep, mkdir |
| close-story cleanup | git, gh authenticated against the repository |

The target project supplies `specs/<ID>.md` as the execution contract,
`CLAUDE.md` and `AGENTS.md` carrying the same rules so both agents receive the
same contract, and optionally an executable `scripts/format-file.sh` for the
Claude edit hook. Without that last one the hook is a safe no-op.

### Environment variables

| Variable | Default | Effect |
|---|---|---|
| `BASE_BRANCH` | resolved from `origin/HEAD`, then the current branch | Base branch for the worktree and the review diff. |
| `WORKTREE_PATH` | `.claude/worktrees/<ID>` or `.agent-worktrees/<ID>` | Where the story worktree is created. |
| `FETCH_BASE` | `1` | Set to `0` to pin the base offline instead of fetching it. |
| `SOT_QUERY` | unset | One narrow Notion query, Jira JQL, or issue URL. The agent uses it exactly once to write the local spec. |
| `PROJECT_VERIFIER` | unset | Path to a verifier outside `scripts/verify-project.sh`. Relative paths resolve against the repository root. |

### Desktop notifications

agent-toast needs an OS notifier. On macOS, `brew install terminal-notifier`
enables the custom icon; without it the plugin falls back to `osascript` and
notifications still work. On Debian or Ubuntu,
`sudo apt install libnotify-bin pulseaudio-utils`; on Fedora,
`sudo dnf install libnotify pulseaudio-utils`. On WSL it needs `wslpath` and
`powershell.exe` reachable, with no PowerShell modules required. On a headless
server it silently skips. Configure it with `/plugin config agent-toast`.

## Tech stack fit

The flow is stack-neutral by construction. No skill hardcodes a language,
framework, package manager, or test runner. The only integration point is the
verifier, so any stack works if its checks run as one command that exits non-zero
on failure.

Rust, Node.js, Go, Java, Python, and .NET repositories are additionally detected
by the generic fallback, so they can run the flow before writing any verifier at
all. Every other stack needs the one file, which `init-verifier.sh` scaffolds as
a `TODO` for you to fill in.

| Stack | Example scripts/verify-project.sh body |
|---|---|
| Node.js / TypeScript | `npm ci && npm run lint && npm run typecheck && npm test && npm run build` |
| Python | `ruff check . && mypy . && pytest -q` |
| Go | `go vet ./... && go test ./... && go build ./...` |
| Rust | `cargo fmt --check && cargo clippy -- -D warnings && cargo test` |
| Java (Maven) | `./mvnw -B verify` |
| Java (Gradle) | `./gradlew --no-daemon build` |
| .NET | `dotnet format --verify-no-changes && dotnet test` |
| Monorepo | Delegate to the workspace runner, for example `pnpm -r verify` or `nx affected -t lint,test,build` |

Stacks that need extra care:

- Mobile and desktop builds, where a full build is slow. Keep the verifier scoped
  to what a story can realistically prove, and record device or store checks as
  human gates.
- UI work, where the visible result is not mechanically checkable. Assert that a
  screenshot artifact exists at an exact path and leave the visual judgment to
  the human gate.
- Repositories whose tests need live credentials or paid services. Gate those
  behind a separate command and keep the story verifier hermetic.

## Working across machines and operating systems

Nothing is tied to one machine, user account, or checkout path. Repository roots
come from `git rev-parse --show-toplevel`, skill assets are addressed relative to
the running script, and the worktree location, base branch, and verifier are all
overridable by environment variable. Two developers can use different clone
paths, different package managers, and different verifiers on the same
repository. Paths containing spaces are supported.

The scripts target POSIX shell and stay compatible with the Bash 3.2 that ships
with macOS.

| Platform | Notes |
|---|---|
| macOS | Works as is. Bash 3.2 is enough; no Homebrew Bash required. |
| Linux | Works as is. |
| Windows | Run everything inside WSL. The scripts need `git worktree`, executable bits, and a POSIX shell. |

On Windows, prefer a clone inside the Linux filesystem, for example
`~/projects/app`, over a path under `/mnt/c` or `/mnt/d`. Repositories on a
Windows drive hit two recurring problems: checkouts arrive with CRLF endings,
which makes `bash` fail with `syntax error near unexpected token $'do\r'`, and
the executable bit may not persist depending on the mount options. If you must
work from a Windows drive, commit a `.gitattributes` with `* text=auto eol=lf`
and set `git config core.autocrlf false` on that clone.

## When not to use these skills

- The change is a typo or an obvious one-line fix. The ceremony costs more than
  the change. Use disciplined-coding alone, or nothing.
- The work is an exploratory spike with no stable acceptance criteria. Come back
  when you know what done means.
- The verifier cannot run locally, because the tests need production credentials
  or a paid service on every run.
- The story cannot be isolated to one branch, or several people are editing the
  same files right now.
- You want the agent to push, open the PR, or merge for you. These skills stop
  before all three, by design, and will not be talked into it.
- The repository is not software. project-setup explicitly does not cover it.

Pick the smallest delivery model that fits the risk:

| Model | Use when | Skill |
|---|---|---|
| Single-agent | Small, tightly coupled, exploratory, or poorly specified work. | disciplined-coding |
| Dual-agent | One material story where an independent reviewer raises confidence. | start-story-multi-agent or codex-multi-agents-flow |
| Multi-agent | Several ready, independent stories with deterministic verification. | One flow run per story, one worktree each |

Parallel activity without independent scope is not throughput. See
[references/delivery-models.md](./claude/plugins/godmode-dev-flow/skills/project-setup/references/delivery-models.md)
for the readiness test.

## Architecture

~~~text
codex/skills/       Codex skills
claude/plugins/     Claude Code plugins and their bundled skills
.claude-plugin/     Claude Code marketplace catalog
docs/               Taxonomy and repository documentation
tests/              Hermetic contract and failure-gate tests
.github/workflows/  Automated verification
~~~

Both platforms use SKILL.md as the skill contract. Codex skills live under
`codex/skills/<skill>/`; Claude skills belong under
`claude/plugins/<plugin>/skills/<skill>/`. Detailed guidance stays in each
skill's `references/` rather than in SKILL.md, so the contract stays short and
the depth is loaded only when needed.

Read [docs/SKILL_TAXONOMY.md](./docs/SKILL_TAXONOMY.md) before adding a skill or
deciding whether a framework-specific workflow is a core skill or an adapter.

## Local development

~~~bash
python3 -m unittest discover -s tests
claude plugin validate . --strict
~~~

The suite uses temporary Git repositories and mocked Claude, Codex, GitHub, and
notification commands, so it calls no paid APIs and mutates nothing outside its
fixtures. It also locks the invariants that are easy to break by accident: both
delivery flows ship the same `verify.sh`, ported skills stay byte-identical,
skill scripts stay `100755` in the index, and every failure gate still stops the
stage after it.

Run shell behavior tests under WSL or POSIX. Run one live canary on every
advertised provider and operating-system integration before publishing.

Keep each skill self-contained: update its SKILL.md, scripts, assets, and
references together.
