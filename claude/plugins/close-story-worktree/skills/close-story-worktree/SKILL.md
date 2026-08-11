---
name: close-story-worktree
description: Safely clean up a story worktree and branch after its pull request has been reviewed and merged. Use this skill whenever the user asks to close, clean up, or tear down a finished story (AL-xxx, HB-xxx, or any PREFIX-nnn ID), says "PR merged rồi", "dọn worktree", "clean up the branch", "remove the worktree", "xong task này rồi", or asks whether a story is safe to delete. Handles codex/ID, worktree-ID, claude/ID, and explicit custom branch or worktree names. Never use before the human merge gate.
---

# Close Story Worktree

Clean up a merged story in a strict order. Keep this skill limited to GitHub
merge verification and local Git cleanup.

## Required inputs

Resolve these before changing state:

- story ID;
- repository root;
- exact head branch;
- exact worktree path;
- PR URL or number;
- base branch.

Read the applicable `CLAUDE.md` (and `AGENTS.md` when the project keeps one for
Codex). Preserve unrelated worktrees and branches. Accept branch forms such as
`codex/AL-151`, `worktree-AL-161`, or `claude/AL-216`; never rewrite one naming
convention into another.

## Sequence

1. Inspect `git status --short --branch` and
   `git worktree list --porcelain`.
2. Use `gh pr view` or the GitHub connector to confirm the exact PR has
   `mergedAt` set and targets the expected base branch.
3. If the PR is open, draft, closed without merge, or ambiguous, stop. Return
   the PR URL and leave the worktree and branch unchanged.
4. Require the story worktree to be clean. Never reset, clean, stash, or force
   removal to make it appear clean.
5. Run `scripts/cleanup-merged-story.sh` without `--apply` to preview the exact
   targets and safety checks.
6. Run the same command with `--apply` only when the user has placed cleanup in
   scope. The script fetches the PR base, verifies the branch tip is an ancestor
   of the updated base, removes the exact worktree without force, then uses
   `git branch -d`.
7. Confirm the path no longer appears in `git worktree list --porcelain` and
   the local branch no longer exists.
8. Report the merged PR, removed worktree, deleted local branch, and any
   intentionally retained remote branch.

## Safety rules

- Never merge the PR. The human reviews and merges.
- Never run cleanup based only on a story ID guess.
- Never use `git worktree remove --force`, `git branch -D`, `git reset`,
  `git clean`, or a recursive filesystem deletion.
- Never remove the primary worktree, repository root, or a dirty worktree.
- Keep source-tracker completion in a separate workflow.
- If a squash merge makes the branch tip not ancestral to the base, stop before
  removal. Ask the user whether to retain the branch or authorize a separate
  recoverability plan.
- Do not delete the remote branch unless the user explicitly requests it.

## Cleanup command

Run from the primary worktree. Requires `gh` and an authenticated
`gh auth status`.

Preview:

~~~bash
"${CLAUDE_SKILL_DIR}/scripts/cleanup-merged-story.sh" AL-151 codex/AL-151
~~~

Apply with an explicit worktree when useful:

~~~bash
"${CLAUDE_SKILL_DIR}/scripts/cleanup-merged-story.sh" AL-151 codex/AL-151 \
  --worktree /absolute/path/to/worktree --apply
~~~

The script verifies merge state and targets in both modes.

## Related

Pairs with `claude-multi-agent-flow`, which opens the story worktree this skill
closes. That flow ends at the human PR gate; this one starts after the merge.
