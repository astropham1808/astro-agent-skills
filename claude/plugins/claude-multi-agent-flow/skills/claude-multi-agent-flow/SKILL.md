---
name: claude-multi-agent-flow
description: Run a story end-to-end using Claude Code as builder and Codex CLI as reviewer, with worktree isolation, spec-first Notion fetch, machine-checkable Done-when criteria, and a human merge gate. Use this skill whenever the user starts, resumes, reviews, or verifies a backlog story (AL-xxx, HB-xxx, or any PREFIX-nnn ID), asks to "bắt đầu task", "start a story", "hand off to Codex", "review this branch", "verify done", or wants to set up a two-agent / multi-agent development workflow on a new project. Also use when the user asks how to split work between Claude Code and Codex, how to save tokens across two AI tools, or how to make an agent pipeline observable and verifiable.
---

# Claude multi-agent story flow

Claude Code = builder (plan, M/L stories, multi-file, debug). Codex CLI = reviewer +
mechanical executor (diff review, S stories, scaffolding). Human = merge gate.

This role split is a workflow default, not a quality or cost guarantee. Select the builder and reviewer based on story scope, available tooling, verification strength, and the repository's own constraints.

## Non-negotiable rules

1. **One story = one worktree = one branch = one owner.** Agents never touch another
   agent's worktree.
2. **Spec-first, fetch-once.** Hit the source of truth (Notion/Jira) exactly once per
   story with the narrowest possible query, write `specs/<ID>.md`, then work only from
   local files. Never fetch full pages.
3. **Diff-only review.** Reviewer reads `git diff main...<branch>`, never the whole repo.
4. **Max 2 review→fix rounds.** Then stop and ask the human. AI↔AI ping-pong is the
   single largest quota sink.
5. **Exit codes decide "done", not agent prose.** `scripts/verify.sh` exit 0 or it isn't
   done.
6. **Humans merge.** No agent merges to `main`, not even a scheduled one.
7. **Branch from fresh `main`.** Rebase (never merge) before PR, so the review diff stays
   scoped to the story.

## Setup (once per project)

```bash
ln -s CLAUDE.md AGENTS.md          # Codex reads AGENTS.md, Claude reads CLAUDE.md
mkdir -p specs notes artifacts
cp assets/spec-template.md specs/_TEMPLATE.md
cp assets/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
# merge assets/settings.hooks.json into .claude/settings.json
```

Codex profiles (v0.134+ format — one file per profile, NOT `[profiles.x]` in config.toml):

```bash
printf 'sandbox_mode = "read-only"\n' > ~/.codex/review.config.toml
printf 'model = "codex-mini-latest"\nsandbox_mode = "workspace-write"\napproval_policy = "on-request"\n' > ~/.codex/mech.config.toml
```

Add the "Non-negotiable rules" above to CLAUDE.md so both agents inherit them.

## Method 1 — CLI

```bash
./scripts/new-story.sh AL-161        # fresh main -> worktree + branch
./scripts/story.sh AL-161            # full pipeline, live-streamed
```

Or step by step:

| Step | Command |
|---|---|
| Spec | `claude -p "ONE SQL query on <collection> for <ID>; write specs/<ID>.md; nothing else from Notion"` |
| Plan | interactive `claude`, Shift+Tab into plan mode, approve |
| Build | same session; commits to its own branch |
| Review | `codex exec -p review -o notes/<ID>-review.md "Review git diff main...<branch> vs specs/<ID>.md"` |
| Fix | `claude --resume` → "address valid findings, max 1 round" |
| Verify | `./scripts/verify.sh` (exit 0) + screenshot for UI stories |
| Merge | human: `gh pr create`, review, merge, `git worktree remove` |

S-size stories invert: human/Claude writes the spec, then
`git worktree add ../<repo>-<ID> -b codex/<ID> origin/main && codex -p mech "Implement specs/<ID>.md"`,
followed by one `claude -p` sanity-check.

**Observability is mandatory.** Never run a bare `claude -p` in a pipeline. Always:
`--output-format stream-json --verbose --max-turns 30 | tee notes/<ID>-trace.jsonl | jq ...`
Three channels required: live feed (what it's doing), trace log (post-mortem), cost line
(what it spent). See `scripts/story.sh` for the jq formatter.

## Method 2 — Desktop apps

Same seven rules, different mechanics. Desktop trades control for convenience: worktrees
are automatic, sandboxed app runs are built in, but you lose profiles, sandbox pinning,
`--max-turns`, and stream logging.

| | CLI | Desktop |
|---|---|---|
| Worktree | `claude --worktree <ID>` | automatic per new session |
| Reviewer read-only | `-p review` sandbox (enforced) | prompt says "Do NOT edit" (trust-based) |
| Observability | stream-json + jq + tee | watch the session UI |
| Cost visibility | `total_cost_usd` per run | dashboard only |
| Verify | `verify.sh` exit code | app auto-runs, but still run `verify.sh` |
| Best for | repeatable pipelines, S stories, batch | exploratory L stories, UI work, debugging |

Desktop procedure per story: new session → paste spec-fetch prompt → plan mode → approve
→ build → "write notes/<ID>.md" → open Codex Desktop, paste diff-review prompt with an
explicit "Do NOT edit code" → paste findings back → run `verify.sh` in terminal → human PR.

Because desktop can't enforce read-only, **compensate with the pre-commit hook and branch
protection** — the guarantees move from sandbox to git.

Recommended split: desktop for the messy front half of an L story (exploration, UI
iteration), CLI for everything repeatable (review, S stories, verification, nightly runs).

## Hook discipline

Cost determines frequency. Never run expensive checks on every edit — it wastes wall-clock
AND injects output into agent context.

| Boundary | Check | Cost |
|---|---|---|
| every edit (PostToolUse) | format the touched file only, silent, `exit 0` | ms |
| agent's own judgment | tests when it decides | let it decide |
| commit (pre-commit hook) | lint -D warnings + tests | seconds |
| PR (CI) | full matrix | minutes |

Rule: things the agent judges well → leave to the agent. Things needing a 100% guarantee →
enforce at a *sparse* boundary (commit/PR), not a dense one (edit).

## Done-when must be machine-readable

In `specs/<ID>.md`, every acceptance criterion is a command, not a sentence.
"UI looks good" is unverifiable and lets the agent grade its own homework. Use the project's exact commands, for example `<unit-test-command> → green`, `<browser-test-command> → pass`, `artifacts/<ID>.png exists`, and `scripts/verify-project.sh → exit 0`. UI claims require a screenshot artifact the human looks at.

## Porting to a new project

Everything above is project-agnostic except four values. Change them and the flow works
anywhere:

1. Story ID prefix (`AL-`)
2. Source-of-truth query (for example a Notion collection URL or Jira JQL)
3. `verify.sh` / `verify-project.sh` body (the project's lint + test + typecheck commands)
4. Branch naming (`worktree-<ID>` for Claude, `codex/<ID>` for Codex)

## Files

- `scripts/new-story.sh` — fresh-main worktree bootstrap
- `scripts/story.sh` — full pipeline with live streaming and verify gate
- `scripts/verify.sh` — the single command that defines "done" (edit per stack)
- `assets/spec-template.md` — spec with machine-readable Done-when
- `assets/settings.hooks.json` — cheap PostToolUse formatter only
- `assets/pre-commit` — the expensive checks, at the right boundary
