---
name: codex-multi-agents-flow
description: Run a repository story through two isolated Codex sessions, with one implementer working in a Git worktree and one independent reviewer inspecting the branch, followed by a bounded fix pass, deterministic verification, and a human PR and merge gate. Use when the user explicitly asks for a dual-agent Codex workflow, an implementer-to-reviewer handoff, a story-ID delivery flow, an independent Codex review of an implementation branch, or repeatable scripts for story delivery. Do not trigger for ordinary one-off coding, generic backlog questions, or reviews that do not need a two-agent workflow.
---

# Codex multi-agent flow

Deliver one scoped story with an implementer session and an independent reviewer
session. Prefer Codex-native worktrees, review commands, JSONL traces, and repository
instructions. Treat another provider such as Claude Code as an optional replacement for
either role, not as a requirement.

## Guardrails

1. Keep one story on one branch and one worktree. Only the implementer may edit it.
2. Preserve the user's current branch and uncommitted changes. Never reset, clean,
   checkout, rebase, push, open a PR, or merge unless the user explicitly places that
   action in scope.
3. Materialize the story in `specs/<ID>.md` before implementation. Use a connected
   source-of-truth tool only when needed, fetch the narrowest sufficient context, and
   retain source links or IDs in the local spec.
4. Start review from the branch diff, then inspect related callers, tests, schemas,
   configuration, and invariants when needed to validate a finding. Do not impose a
   diff-only context limit.
5. Require each finding to include severity, file and line, failure scenario, and a
   minimal correction. Report no finding when evidence is insufficient.
6. Allow at most one fix pass and one optional re-review. Escalate unresolved design
   decisions to the user instead of starting agent-to-agent loops.
7. Define completion with commands and artifacts. Agent prose is not verification.
8. Keep PR creation and merge as explicit human gates.

## Prepare the story

Read all applicable `AGENTS.md` files and inspect the repository before choosing
commands. Determine the base branch from repository context instead of assuming `main`.

Create or update `specs/<ID>.md` from `assets/spec-template.md`. Replace every
placeholder. Acceptance criteria must name an exact command or artifact check whenever
the criterion is mechanically testable. Record non-mechanical judgments as human gates.

Run the worktree helper from the primary worktree:

```bash
<skill-dir>/scripts/new-story.sh <ID> [base-branch]
```

The helper fetches the base branch when `origin` exists, creates
`codex/<ID>` under `.agent-worktrees/<ID>`, and does not switch the user's current
branch. Set `FETCH_BASE=0` only when an offline or intentionally pinned base is desired.
Commits are allowed only inside the isolated story branch. Push remains a human gate.

## Run the Codex-first pipeline

Before automation, configure a deterministic repository verifier. Prefer a
project-owned `scripts/verify-project.sh`. The bundled `scripts/verify.sh` is a generic
fallback for common Rust, Node.js, Go, and Python repositories.

Run:

```bash
<skill-dir>/scripts/story.sh <ID> [base-branch]
```

The script performs these bounded stages:

1. Start a fresh Codex implementer session in the story worktree.
2. Require the implementer to commit the scoped spec, code, and tests, then run the
   verification gate before review.
3. Start a separate native `codex review --base <branch>` reviewer.
4. Skip the fix pass on `VERDICT: PASS`; otherwise run one fresh fix session and require
   it to commit accepted corrections.
5. Run final verification and re-review after a fix. Set `REREVIEW=0` only when the
   user explicitly prefers the lower-cost path.
6. Print the branch, worktree, notes, and suggested human commands without pushing or
   opening a PR.

The implementer uses `codex exec --json` with a workspace-write sandbox and writes
JSONL traces plus its final message under the ignored `.codex-flow/<ID>/` directory.
The reviewer uses Codex's dedicated review command, which reviews without modifying the
working tree.

## Operate interactively

When the user prefers the Codex app or interactive CLI:

1. Create or select an isolated worktree for the story.
2. Give the implementer `specs/<ID>.md` and the applicable `AGENTS.md`.
3. Require targeted checks and a scoped commit before handoff.
4. Start an independent review with `/review`, choosing the base-branch scope.
5. Give valid findings back to the implementer for one fix pass and one scoped commit.
6. Run the project verifier and collect UI screenshots or other artifacts.
7. Summarize readiness and stop at the human PR or merge gate.

If multi-agent tools are available and the user explicitly requested this dual-agent
workflow, assign implementation and review as separate roles. Do not allow concurrent
writes to the same worktree. Start the reviewer only after implementation has stopped.

## Cross-provider option

Keep the worktree, spec, verification, review rubric, and human gates unchanged when
using Claude Code or another agent for one role. Run providers as separate sessions and
do not make unverified claims that one provider is always more accurate or cheaper.
Prefer the Codex-first scripts unless the user explicitly chooses a different builder.

## Review output contract

Require the first line to be exactly one of:

```text
VERDICT: PASS
VERDICT: CHANGES_REQUESTED
```

For changes requested, require a severity-ordered checklist. Each item must state:

- severity: P0, P1, or P2;
- file and line;
- concrete failure scenario;
- why current tests do not prevent it, when relevant;
- smallest safe correction.

Exclude style preferences, speculative risks without a reachable scenario, and issues
outside the story unless the change directly creates them.

## Handoff

Return:

- story ID, branch, base branch, and worktree path;
- implemented scope and intentional exclusions;
- review verdict and accepted or rejected findings;
- exact verification commands and exit status;
- artifact paths;
- unresolved risks or decisions;
- suggested PR command only when useful.

Never claim the story is done when verification did not run or returned nonzero.
