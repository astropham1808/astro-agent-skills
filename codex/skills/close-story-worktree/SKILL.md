---
name: close-story-worktree
description: Safely clean up a repository story or merged local branch after its pull request has been reviewed and merged. Verifies the exact PR, removes a clean Git worktree when one exists, and deletes the merged local branch. Supports story IDs and explicit branch names. Never use before the human merge gate.
---

# Close Story Worktree

Clean up a merged story in a strict order. Keep this skill limited to GitHub
merge verification and local Git cleanup.

## Required inputs

Resolve these before changing state:

- story ID when one exists;
- repository root;
- exact head branch;
- exact worktree path when the branch is checked out outside the primary worktree;
- PR URL or number;
- base branch.

Read applicable `AGENTS.md` files. Preserve unrelated worktrees and branches.
Accept branch forms such as `codex/AL-151`, `worktree-AL-161`, or
`claude/AL-216`; never rewrite one naming convention into another.

## Sequence

1. Inspect `git status --short --branch` and
   `git worktree list --porcelain`.
2. Use `gh pr view` or the GitHub connector to confirm the exact PR has
   `mergedAt` set and targets the expected base branch.
3. If the PR is open, draft, closed without merge, or ambiguous, stop. Return
   the PR URL and leave the worktree and branch unchanged.
4. If the branch has a worktree, require it to be clean. Never reset, clean,
   stash, or force removal to make it appear clean. If it has no worktree,
   continue with local-branch-only cleanup.
5. Run `scripts/cleanup-merged-story.sh` without `--apply` to preview the exact
   targets and safety checks.
6. Run the same command with `--apply` only when the user has placed cleanup in
   scope. The script fetches the PR base, verifies the branch tip is an ancestor
   of the updated base, removes the exact worktree without force when present,
   then uses `git branch -d`.
7. Confirm any targeted worktree path no longer appears in
   `git worktree list --porcelain` and the local branch no longer exists.
8. Report the merged PR, removed worktree, deleted local branch, and any
   intentionally retained remote branch.

## Safety rules

- Never merge the PR. The human reviews and merges.
- Never run cleanup based only on a story ID guess. An explicit local branch
  may be cleaned without a story ID after the exact merged PR is verified.
- Never use `git worktree remove --force`, `git branch -D`, `git reset`,
  `git clean`, or a recursive filesystem deletion.
- Never remove the primary worktree, repository root, or a dirty worktree.
- Keep source-tracker completion in a separate workflow.
- If a squash merge makes the branch tip not ancestral to the base, stop before
  removal. Ask the user whether to retain the branch or authorize a separate
  recoverability plan.
- Do not delete the remote branch unless the user explicitly requests it.

## Cleanup command

Preview:

```bash
scripts/cleanup-merged-story.sh AL-151 codex/AL-151
```

Preview a merged branch that has no story ID or worktree:

```bash
scripts/cleanup-merged-story.sh codex/fix-fleet-shell
```

Apply with an explicit worktree when useful:

```bash
scripts/cleanup-merged-story.sh AL-151 codex/AL-151 \
  --worktree /absolute/path/to/worktree --apply
```

The script verifies merge state and targets in both modes.
