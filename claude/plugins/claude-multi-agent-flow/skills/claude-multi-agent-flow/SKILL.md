---
name: claude-multi-agent-flow
description: Run backlog stories in parallel across several agents, one worktree ("berth") each, with Claude Code building, Codex CLI reviewing read-only, and a human merging. Covers berth bootstrap, spec-first fetch-once, risk-routed review, exclusive-resource locks, a WIP cap, a serialised landing queue, and a board derived from git rather than from agent self-reports. Use this skill whenever the user starts, resumes, reviews, lands, or verifies a backlog story (AL-xxx, HB-xxx, or any PREFIX-nnn ID), asks to "bắt đầu task", "start a story", "open a berth", "what is in flight", "hand off to Codex", "review this branch", "land this", or "verify done". Also use when setting up a multi-agent development workflow on a new project, splitting work between Claude Code and Codex, or making an agent pipeline observable and verifiable.
---

# Claude multi-agent story flow

Several stories run at once. Each gets a berth: one worktree, one branch, one
owner. Claude Code builds, Codex CLI reviews in a read-only sandbox, a human
merges. Nothing here trusts an agent's account of its own work.

Rationale: Claude Code has higher first-pass accuracy, and rework is what
actually burns quota; Codex is cheaper on narrow, well-specified scope, and a
second model reviewing is worth more than the same model reviewing itself.

## Non-negotiable rules

1. **One story = one berth = one branch = one owner.** Branch `<owner>/<ID>`,
   worktree `../<repo>-<ID>`. An agent never touches another agent's berth.
2. **Spec-first, fetch-once.** Query the source of truth exactly once per story,
   with the narrowest query that works, write `specs/<ID>.md`, then work only
   from local files. Never fetch full pages.
3. **Diff-only review.** The reviewer reads `git diff <base>...<branch>`, never
   the repository. Size picks the builder; risk picks the reviewer.
4. **Claim before you touch.** Anything only one story can use at a time is
   declared in `EXCLUSIVE` and held through `claim.sh`.
5. **Max 2 review→fix rounds,** then stop and ask the human. Agent-to-agent
   ping-pong is the single largest quota sink.
6. **Exit codes decide done, not agent prose.** `VERIFY` exits 0 or it is not done.
7. **One story lands at a time,** and **humans merge.** No agent merges to base.
8. **Berths are found by asking git,** never by rebuilding a path from a naming
   convention. A worktree made by hand resolves the same as a generated one.

Copy rules 1-7 into the repository's own instructions file (`CLAUDE.md`,
symlinked to `AGENTS.md`) so every agent inherits them without being told.

## Setup, once per project

```bash
ln -s CLAUDE.md AGENTS.md                       # Codex reads AGENTS.md
mkdir -p specs notes artifacts scripts
cp scripts/* <repo>/scripts/                    # from this skill
cp assets/agentflow.conf.example <repo>/.agentflow.conf   # then edit it
cp assets/spec-template.md specs/_TEMPLATE.md
cp assets/verify.sh.example scripts/verify.sh   # then edit per stack
hooks="$(git rev-parse --git-common-dir)/hooks"
cp assets/pre-commit "$hooks/pre-commit" && chmod +x "$hooks/pre-commit"
# merge assets/settings.hooks.json into .claude/settings.json
```

`.agentflow.conf` is the only file that knows about the project. Everything in
`scripts/` reads it and nothing else, which is what makes the flow portable:
`PREFIX`, `SOT`, `BASE`, the two naming patterns, `VERIFY`, `WIP_CAP`,
`EXCLUSIVE`, `RISKY_PATHS`, and the three Codex profile names.

Install the hook into the **common** dir, not `.git/hooks/`. In a berth `.git`
is a file, not a directory, so the usual form fails there; the common dir is
shared by every worktree, so berths inherit the hook instead of each needing
its own copy.

Codex profiles are one file per profile (v0.134+), not `[profiles.x]` blocks:

```bash
printf 'sandbox_mode = "read-only"\n' > ~/.codex/review.config.toml
printf 'model = "gpt-5-codex"\nmodel_reasoning_effort = "high"\nsandbox_mode = "read-only"\n' > ~/.codex/deepreview.config.toml
printf 'sandbox_mode = "workspace-write"\napproval_policy = "on-request"\n' > ~/.codex/mech.config.toml
```

Both reviewers are `read-only`, so "do not edit" is enforced by the sandbox
rather than requested in a prompt.

## The loop

```bash
scripts/new-story.sh AL-161 claude   # berth from fresh origin/main
scripts/story.sh     AL-161          # spec -> build -> review -> fix -> verify
scripts/board.sh                     # what is in flight, any time
scripts/land.sh      AL-161          # rebase -> re-verify -> PR. Human merges.
```

| Script | What it is for |
|---|---|
| `new-story.sh <ID> <owner>` | Berth from a *fresh* base, so the review diff stays scoped to the story. Refuses past `WIP_CAP`. Checks nothing out in the primary worktree, so opening a berth never disturbs work there. |
| `story.sh <ID> [--dry-run]` | The four steps, live-streamed. Picks `review` or `deepreview` from what the diff touches. Writes `notes/<ID>-trace.jsonl`, prints cost. `--dry-run` shows routing and lock warnings without spending anything. |
| `board.sh` | One line per story: phase, commits behind base, cost so far, locks held. Also lists files two in-flight branches both changed, which is the conflict nobody declared in advance. |
| `claim.sh` | `list` / `take` / `release` / `drop`. Locks are directories in the shared common dir, because `mkdir` is atomic. |
| `land.sh <ID>` | Serialised on one lock: rebase onto fresh base, mandatory re-verify, push, open the PR. Never merges. |
| `agentflow-lib.sh` | Sourced by the rest. Config, berth resolution, locks, routing. Not run directly. |

S-size stories can invert: a human or Claude writes the spec, then
`codex -p mech "Implement specs/<ID>.md"` in a `codex/<ID>` berth, followed by
one `claude -p` sanity check.

## Why each guard exists

**WIP cap.** Berths are not free. Each is a cold build tree of its own, and the
pre-commit hook runs the full suite in each. Set `WIP_CAP` from what the machine
will take, not from ambition.

**Berths as siblings, never nested.** A worktree inside the working tree is seen
by anything watching the repo for file events. A berth's build output then
arrives as changes to the repository the user is looking at. `.git/info/exclude`
does not fix this: it is local to one clone and travels with nobody.

**Owner in the branch name.** Rule 1 says a story has exactly one owner. Putting
it in the ref means the board, the reviewer, and anyone reading `git branch` see
who is accountable without opening anything.

**Resolution by git, not by pattern.** An earlier version rebuilt berth paths
from a hardcoded convention and could not see three of the four berths that
actually existed, exiting "no worktree" on stories that plainly had one. The
truth is `git worktree list --porcelain`, never a side file that can drift.

**Locks.** `EXCLUSIVE` covers what somebody thought to declare ahead of time,
and it is worth declaring the obvious ones: a fixed dev-server port with
`strictPort`, a generated tokens file, a strings file, a serde type and its
TypeScript mirror. Nothing enforces a lock at the filesystem level; the point is
that a collision is discovered before the work, not at merge. What nobody
foresaw is what `board.sh`'s overlap check catches.

**Serialised landing.** The first branch to merge invalidates every other
branch's base. Two stories rebasing and verifying against the same base at once
means one of them verified against a base that no longer exists.

**Failure is not approval.** If the reviewer step exits non-zero, or writes no
findings file, that is a failed review, not a clean one. `story.sh` dies there
rather than letting the fix step read an absent file and call it "no findings".

## Observability is mandatory

Never run a bare `claude -p` in a pipeline. Every model step needs three
channels: a live feed of what it is doing, a trace for the post-mortem, and what
it spent.

```
claude -p "…" --output-format stream-json --verbose --max-turns 30 \
  | tee -a notes/<ID>-trace.jsonl | jq -r '…'
```

See `run_claude` in `scripts/story.sh` for the jq formatter. `board.sh` sums
`total_cost_usd` across each story's trace.

## Hook discipline

Cost determines frequency. An expensive check on every edit wastes wall-clock
*and* injects its output into the agent's context.

| Boundary | Check | Cost |
|---|---|---|
| every edit (PostToolUse) | format the touched file only, silent, `exit 0` | ms |
| the agent's own judgment | tests, when it decides it needs them | let it decide |
| every commit (pre-commit) | lint `-D warnings` + tests | seconds |
| every PR (CI) | the full matrix | minutes |

Rule: what the agent judges well, leave to the agent. What needs a 100%
guarantee, enforce at a *sparse* boundary, not a dense one.

The hook must `unset GIT_DIR` and its siblings first. Git exports them into
hooks, and every git spawned by the hook's own tests inherits them; if the suite
builds throwaway repositories, a `git init` in a fixture reconfigures the real
one. That is not theoretical, it cost a repository once.

## Done-when must be machine-readable

In `specs/<ID>.md`, every acceptance criterion is a command, not a sentence.
"UI looks good" is unverifiable and lets the agent grade its own homework. Use
`cargo test <mod>:: -> green`, `npx playwright test tests/<ID>.spec.ts -> pass`,
`artifacts/<ID>.png exists`, `scripts/verify.sh -> exit 0`. A UI claim needs a
screenshot artifact a human actually looks at.

`board.sh` derives phase the same way: spec file exists, commits exist, review
file exists, verify log says passed. No step is believed because an agent said so.

## Desktop apps instead of the CLI

Same rules, different mechanics. Desktop trades control for convenience.

| | CLI | Desktop |
|---|---|---|
| Berth | `new-story.sh` | automatic per session |
| Reviewer read-only | sandbox (enforced) | prompt says "do not edit" (trust) |
| Observability | stream-json + jq + tee | the session UI |
| Cost | `total_cost_usd` per run | dashboard only |
| Verify | `verify.sh` exit code | still run `verify.sh` |
| Best for | repeatable pipelines, S stories, batch | exploratory L stories, UI work, debugging |

Because desktop cannot enforce read-only, compensate with the pre-commit hook
and branch protection: the guarantee moves from sandbox to git. A reasonable
split is desktop for the messy front half of an L story, CLI for everything
repeatable.

## On close

Write `notes/<ID>.md`: what was done, decisions taken, open questions. After the
human merges, `scripts/claim.sh drop <ID>` and `git worktree remove <berth>`.

## Files

- `scripts/agentflow-lib.sh` - config, berth resolution, locks, routing
- `scripts/new-story.sh` - berth bootstrap from a fresh base, WIP-capped
- `scripts/story.sh` - the four steps, streamed, with routing and lock warnings
- `scripts/board.sh` - what is in flight, derived from git and artifacts
- `scripts/claim.sh` - exclusive-resource locks
- `scripts/land.sh` - serialised rebase, re-verify, PR
- `assets/agentflow.conf.example` - the only project-specific file
- `assets/verify.sh.example` - the single definition of done, edit per stack
- `assets/spec-template.md` - spec shape with machine-readable Done-when
- `assets/settings.hooks.json` - the cheap PostToolUse formatter only
- `assets/pre-commit` - the expensive checks, at the right boundary
