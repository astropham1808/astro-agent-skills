---
name: claude-multi-agent-flow
description: Run a repository story through Claude Code as implementer and Codex CLI as an independent reviewer, using an isolated Git worktree, a local machine-checkable spec, project-owned verification, one bounded fix pass, and human PR and merge gates. Use when the user starts, resumes, reviews, or verifies a story ID; asks to hand work from Claude to Codex; or wants to set up this two-agent delivery workflow. Support a local request, Notion, Jira, or another source of truth without requiring one provider.
---

# Claude multi-agent story flow

Use Claude Code to implement, Codex CLI to review in a read-only sandbox, and the
human to open, review, and merge the pull request. Treat this split as a workflow
default, not a quality or cost guarantee.

## Enforce the contract

1. Use one story, one worktree, one branch, and one active implementer.
2. Make specs/<ID>.md the local execution contract. If a remote source is needed,
   query it exactly once with the narrowest sufficient query, then work locally.
3. Resolve the base from origin/HEAD, BASE_BRANCH, or an explicit script argument.
   Never checkout or pull the primary worktree to create a story.
4. Review only the base-to-branch diff plus files needed to validate a concrete finding.
5. Allow at most one review-to-fix pass, followed by one re-review.
6. Let executable verification and exit codes decide whether work is ready.
7. Stop before push, PR creation, merge, rebase, or worktree removal. A human owns
   those external and destructive gates.
8. Keep trace and review artifacts under the story worktree's ignored
   .claude-flow/<ID>/ directory.

## Set up a project

Require Git, Claude Code, Codex CLI, jq, and the repository's own development
toolchain. Run setup from the target project root:

~~~bash
mkdir -p specs artifacts scripts .claude/hooks
cp "${CLAUDE_SKILL_DIR}/assets/spec-template.md" specs/_TEMPLATE.md
cp "${CLAUDE_SKILL_DIR}/assets/format-hook.sh" .claude/hooks/format-file.sh
chmod +x .claude/hooks/format-file.sh
~~~

Create executable scripts/verify-project.sh with the project's exact lint,
typecheck, test, and build commands. Run it successfully before installing the
commit gate:

~~~bash
scripts/verify-project.sh
cp "${CLAUDE_SKILL_DIR}/assets/pre-commit" .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
~~~

Merge ${CLAUDE_SKILL_DIR}/assets/settings.hooks.json into
.claude/settings.json. Optionally provide executable scripts/format-file.sh;
it receives the absolute path of the file touched by Claude. Without it, the edit
hook is a safe no-op.

Put the same repository rules and verification command in CLAUDE.md and
AGENTS.md so both agents receive the delivery contract.

## Run with a local spec

~~~bash
"${CLAUDE_SKILL_DIR}/scripts/new-story.sh" AL-161
# Complete .claude/worktrees/AL-161/specs/AL-161.md.
"${CLAUDE_SKILL_DIR}/scripts/story.sh" AL-161
~~~

Pass a non-default base branch as the second argument or set BASE_BRANCH.

## Run with a remote source of truth

~~~bash
"${CLAUDE_SKILL_DIR}/scripts/new-story.sh" AL-161 trunk
SOT_QUERY='<one narrow Notion query, Jira JQL, issue URL, or equivalent>' \
  "${CLAUDE_SKILL_DIR}/scripts/story.sh" AL-161 trunk
~~~

The query is configuration, not a provider assumption. The pipeline asks Claude to
use it once, write the local spec, and avoid additional remote fetches.

## Observe the pipeline

The automated path is:

1. Claude implements and commits inside worktree-<ID>.
2. Project verification passes before review.
3. Codex reviews in an explicit read-only sandbox and writes VERDICT: PASS or
   VERDICT: CHANGES_REQUESTED.
4. Claude performs at most one committed fix pass.
5. Project verification and, when needed, Codex re-review pass.
6. The script prints a suggested gh pr create command and stops.

Every Claude and Codex run writes a JSONL trace under .claude-flow/<ID>/; Codex
reviews also write a separate final verdict file there. A failed stage stops all
later stages.

## Write machine-checkable specs

Express every Done-when item as an executable command or an artifact assertion.
Use the repository's real commands, for example:

- scripts/verify-project.sh exits 0.
- A focused regression test command passes.
- A required artifact exists at an exact path.
- A UI screenshot exists for human visual review.

Do not use subjective criteria such as “UI looks good” as the only acceptance
evidence.

## Use desktop sessions manually

Keep the same spec, worktree, review, verification, and human gates when using
desktop apps. Desktop prompts cannot enforce a read-only reviewer as strongly as
the CLI, so rely on branch protection, the pre-commit verifier, and a final CLI
verification before the human opens a PR.

## Bundled files

- scripts/new-story.sh: create an isolated worktree without changing the primary branch.
- scripts/story.sh: run build, verify, review, bounded fix, and final gates.
- scripts/verify.sh: delegate to the target project's verifier.
- assets/spec-template.md: local story contract template.
- assets/format-hook.sh: extract the edited path from Claude hook JSON.
- assets/settings.hooks.json: invoke the copied project hook.
- assets/pre-commit: enforce the project verifier at commit time.
