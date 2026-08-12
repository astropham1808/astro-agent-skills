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

| Plugin | Scope |
|---|---|
| [godmode-dev-flow](./claude/plugins/godmode-dev-flow/) | The full story delivery lifecycle, four skills in one install. |
| [agent-toast](./claude/plugins/agent-toast/) | Claude lifecycle notifications on Windows/WSL, macOS, and Linux. No skills; hooks only. |

godmode-dev-flow bundles these skills. Claude invokes a bundled skill as
`plugin:skill`, so the call names are:

| Category | Skill | Call | Scope |
|---|---|---|---|
| Planning and setup | [project-setup](./claude/plugins/godmode-dev-flow/skills/project-setup/) | `godmode-dev-flow:project-setup` | Cross-stack product and repository planning. |
| Foundation | [disciplined-coding](./claude/plugins/godmode-dev-flow/skills/disciplined-coding/) | `godmode-dev-flow:disciplined-coding` | Cross-stack coding quality, scope control, and verification. |
| Delivery orchestration | [start-story-multi-agent](./claude/plugins/godmode-dev-flow/skills/start-story-multi-agent/) | `godmode-dev-flow:start-story-multi-agent` | Claude implementer + read-only Codex reviewer with configurable source, base branch, and project verification. |
| Repository lifecycle | [close-story](./claude/plugins/godmode-dev-flow/skills/close-story/) | `godmode-dev-flow:close-story` | GitHub PR and Git worktree cleanup after the human merge gate. |

Every Codex skill has a Claude Code counterpart. The two delivery-orchestration
skills stay separate because they automate different provider CLIs; the other
three are ports that share their scripts, assets, and references byte for byte
with the Codex originals.

### Install a Claude Code plugin

~~~text
/plugin marketplace add https://github.com/astropham1808/astro-agent-skills
/plugin install godmode-dev-flow@astro-agent-skills
/plugin install agent-toast@astro-agent-skills
~~~

Pull later changes with /plugin marketplace update astro-agent-skills, then update
the installed plugin with /plugin update <plugin>@astro-agent-skills.

Upgrading from the pre-2.0 catalog: the four separate story plugins were merged
into godmode-dev-flow. Uninstall the old ones first, since plugin names are the
install key.

~~~text
/plugin uninstall claude-multi-agent-flow@astro-agent-skills
/plugin uninstall close-story-worktree@astro-agent-skills
/plugin uninstall disciplined-coding@astro-agent-skills
/plugin uninstall project-setup@astro-agent-skills
~~~

agent-toast can be configured with an agent name, optional session label,
optional PNG icon path, and optional beep. Reopen its settings with
/plugin config agent-toast.

The Claude multi-agent flow keeps its provider-specific mechanics, but its story
template, verifier, and formatter hook are stack-neutral. Projects provide their
own executable scripts/verify-project.sh and optional scripts/format-file.sh.

## When to use the delivery flow

The two delivery-orchestration skills (start-story-multi-agent for Claude Code,
codex-multi-agents-flow for Codex) automate one story at a time. They pay off only
when the work is scoped and the definition of done is mechanical.

Use the flow when all of these hold:

- The work is one story-sized unit with an ID matching `PREFIX-nnn`, for example
  `AL-161`. The scripts reject any other shape.
- The repository is a Git repository, and a base branch is resolvable from
  `origin/HEAD`, from `BASE_BRANCH`, or as an explicit argument.
- Acceptance criteria can be written as commands or artifact assertions, not as
  subjective judgments.
- A deterministic verifier exists or can be written, and it exits non-zero on
  failure.
- You accept that push, PR creation, and merge stay human gates. Neither flow
  performs them.

Skip the flow when the change is a typo or an obvious one-line fix, when the work
is an exploratory spike with no stable acceptance criteria, when the verifier
cannot run locally, or when the story cannot be isolated to one branch. Reach for
disciplined-coding alone in those cases.

Pick the delivery model before automating anything:

| Model | Use when | Skill |
|---|---|---|
| Single-agent | Small, tightly coupled, exploratory, or poorly specified work. | disciplined-coding |
| Dual-agent | One material story where an independent reviewer raises confidence. | start-story-multi-agent or codex-multi-agents-flow |
| Multi-agent | Several ready, independent stories with deterministic verification. | One flow run per story, one worktree each |

Parallel activity without independent scope is not throughput. See
[references/delivery-models.md](./claude/plugins/godmode-dev-flow/skills/project-setup/references/delivery-models.md)
for the readiness test.

### Prerequisites

The scripts check their own dependencies and exit 2 with the missing command name.

| Stage | Required on PATH |
|---|---|
| new-story.sh (both flows) | git, mkdir, cp, grep, sed, rm |
| start-story-multi-agent story.sh | claude, codex, git, tee, jq, grep, mkdir |
| codex-multi-agents-flow story.sh | codex, git, tee, grep, mkdir |
| close-story cleanup | git, gh authenticated against the repository |

A POSIX shell is required. On Windows, run everything inside WSL. Git must be new
enough for `git worktree`. Both flows need the target project's own toolchain
available, since verification runs the project's real commands.

The target project must also provide:

- `specs/<ID>.md`, the local execution contract;
- `CLAUDE.md` and `AGENTS.md` carrying the same repository rules, so both agents
  receive the same contract;
- a definition of done, resolved as described below. A project-owned
  `scripts/verify-project.sh` is strongly preferred but not required to start;
- optional executable `scripts/format-file.sh` for the Claude edit hook. Without
  it the hook is a safe no-op.

### How verification resolves

Both flows share one `scripts/verify.sh`, which resolves the definition of done
in a fixed order:

1. `PROJECT_VERIFIER`, absolute or relative to the repository root, for projects
   that already keep their checks somewhere else.
2. `scripts/verify-project.sh`, the preferred project-owned verifier.
3. Generic checks detected from `Cargo.toml`, `package.json` with its lockfile's
   package manager, `go.mod`, `pom.xml` or a Gradle build, `pyproject.toml`,
   or a .NET project file.

A repository with no recognizable stack and no verifier stops with exit 2 rather
than passing by default. A verifier that exists but lost its executable bit, a
common result of a Windows checkout, also stops, with a `chmod +x` hint instead
of being silently skipped.

### Environment variables

| Variable | Default | Effect |
|---|---|---|
| `BASE_BRANCH` | resolved from `origin/HEAD`, then the current branch | Base branch for the worktree and the review diff. |
| `WORKTREE_PATH` | `.claude/worktrees/<ID>` or `.agent-worktrees/<ID>` | Where the story worktree is created. |
| `FETCH_BASE` | `1` | Set to `0` to pin the base offline instead of fetching it. |
| `SOT_QUERY` | unset | One narrow Notion query, Jira JQL, or issue URL. The agent uses it exactly once to write the local spec. |
| `PROJECT_VERIFIER` | unset | Path to a verifier outside `scripts/verify-project.sh`. Relative paths resolve against the repository root. |

Every path is resolved at run time from `git rev-parse --show-toplevel` and the
script's own location, so the skills work from any checkout directory, any user
account, and any clone name. Paths containing spaces are supported.

## End-to-end usage

### 0. Quickstart when the repository has none of these files

A repository that has never seen these skills needs one file, and even that can
be generated. From the project root:

~~~bash
# preview what would be generated, change nothing
"${CLAUDE_SKILL_DIR}/scripts/init-verifier.sh" --print

# write scripts/verify-project.sh and mark it executable
"${CLAUDE_SKILL_DIR}/scripts/init-verifier.sh"
~~~

The scaffold lives in the project-setup skill. It detects the stack from the
repository's own markers, writes the matching lint, typecheck, test, and build
commands, and never overwrites an existing verifier without `--force`. When it
finds no recognizable stack it writes a `TODO` verifier that exits non-zero, so
an unconfigured project fails loudly rather than reporting a fake pass.

Review the generated commands, run `scripts/verify-project.sh` once, then move on
to the full setup below. If your checks already live elsewhere, skip the file
entirely and point `PROJECT_VERIFIER` at them.

Use `--root <path>` to scaffold a repository other than the current directory.

### 1. Prepare the project once

From the target project root, with the skill installed:

~~~bash
mkdir -p specs artifacts scripts .claude/hooks
cp "${CLAUDE_SKILL_DIR}/assets/spec-template.md" specs/_TEMPLATE.md
cp "${CLAUDE_SKILL_DIR}/assets/format-hook.sh" .claude/hooks/format-file.sh
chmod +x .claude/hooks/format-file.sh
~~~

Write executable `scripts/verify-project.sh` with the project's real lint,
typecheck, test, and build commands, run it successfully, then install the commit
gate and merge `assets/settings.hooks.json` into `.claude/settings.json`:

~~~bash
scripts/verify-project.sh
cp "${CLAUDE_SKILL_DIR}/assets/pre-commit" .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
~~~

For a greenfield or unfamiliar repository, run project-setup first. It classifies
the product, produces the plan, backlog, engineering guide, and the verification
contract this flow depends on.

### 2. Open the story

~~~bash
"${CLAUDE_SKILL_DIR}/scripts/new-story.sh" AL-161            # base from origin/HEAD
"${CLAUDE_SKILL_DIR}/scripts/new-story.sh" AL-161 trunk      # explicit base
~~~

This creates branch `worktree-AL-161` in an isolated worktree without touching the
primary branch or your uncommitted changes. Complete
`.claude/worktrees/AL-161/specs/AL-161.md`, expressing every Done-when item as an
executable command or an artifact assertion.

### 3. Run the pipeline

~~~bash
"${CLAUDE_SKILL_DIR}/scripts/story.sh" AL-161
~~~

With a remote source of truth instead of a hand-written spec:

~~~bash
SOT_QUERY='<one narrow Notion query, Jira JQL, or issue URL>' \
  "${CLAUDE_SKILL_DIR}/scripts/story.sh" AL-161
~~~

The stages are: implement and commit, verify, independent read-only review with a
`VERDICT: PASS` or `VERDICT: CHANGES_REQUESTED` line, at most one committed fix
pass, re-verify and re-review when needed. A failed stage stops every later stage.
Traces land in the worktree's ignored `.claude-flow/<ID>/`. The script prints a
suggested `gh pr create` command and stops there.

### 4. Human gate, then close the story

You review, push, open the PR, and merge. Afterwards, invoke close-story. It
confirms `mergedAt` on the exact PR, requires a clean worktree, previews the
cleanup, and only then removes the worktree and deletes the local branch with
`git branch -d`. It never force-removes, never merges, and never deletes the
remote branch unless you ask.

## Tech stack fit

The flow is stack-neutral by construction. No skill hardcodes a language,
framework, package manager, or test runner. The only integration point is the
verifier, so any stack works if its checks can run as one command that exits
non-zero on failure.

Rust, Node.js, Go, Java, Python, and .NET repositories are additionally detected by the
generic fallback, so they can run the flow before writing any verifier at all.
Every other stack needs the one file, which `init-verifier.sh` will scaffold as a
`TODO` for you to fill in.

What actually constrains adoption is the environment, not the language: a POSIX
shell, Git worktree support, and a toolchain that runs locally without a paid or
interactive external step.

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
  screenshot artifact exists at an exact path and leave the visual judgment to the
  human gate.
- Repositories whose tests need live credentials or paid services. Gate those
  behind a separate command and keep the story verifier hermetic.
- Non-software repositories, which project-setup explicitly does not cover.

### Working across machines and operating systems

Nothing in the skills is tied to one machine, user account, or checkout path.
Repository roots come from `git rev-parse --show-toplevel`, skill assets are
addressed relative to the running script, and the worktree location, base branch,
and verifier are all overridable by environment variable. Two developers can use
different clone paths, different package managers, and different verifiers on the
same repository.

The scripts target POSIX shell and stay compatible with the Bash 3.2 that ships
with macOS. Practical notes per platform:

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
