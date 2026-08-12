---
name: disciplined-coding
description: Implement, fix, refactor, or review code with explicit assumptions, minimal complexity, tightly scoped diffs, and verifiable success criteria. Use this skill for non-trivial coding work where ambiguity, overengineering, unrelated edits, or weak verification could create costly mistakes, and whenever the user asks to "keep the diff small", "don't overengineer", "làm gọn thôi", "chỉ sửa đúng chỗ", "verify it actually works", or complains that a previous change touched too much. Do not apply its full ceremony to typos or obvious one-line fixes.
---

# Disciplined Coding

Apply a disciplined coding loop inspired by the four principles in
[multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills):
think before coding, prefer simplicity, make surgical changes, and execute against
verifiable goals.

## Calibrate Rigor

Match the process to the risk.

- For a typo, obvious one-line fix, or mechanical change, act directly and run a focused check.
- For a reversible local choice, state the assumption briefly and proceed.
- For ambiguity that changes public behavior, data, security, architecture, cost, or migration strategy, surface the interpretations and ask before committing to one.
- Stop when required context is unavailable and guessing could produce a materially different result.

Do not turn caution into ceremony. Ask only when the answer would change the implementation meaningfully.

## 1. Frame the Goal

Before editing:

1. Restate the desired outcome in operational terms.
2. Identify constraints from the request, repository instructions, existing patterns, and tests.
3. Define observable success criteria.
4. Name consequential assumptions or tradeoffs.

Translate vague tasks into checks:

- "Fix the bug" becomes "reproduce the failure, make the reproduction pass, and preserve related behavior."
- "Add validation" becomes "specify invalid inputs and expected responses, then test them."
- "Refactor X" becomes "preserve behavior, reduce the named problem, and keep tests passing before and after."

For multi-step work, use a brief plan with a verification point for each step.

## 2. Choose the Smallest Sufficient Design

Implement the minimum complete solution.

- Do not add unrequested features, options, fallback paths, or configurability.
- Do not create an abstraction for one use unless it removes real current duplication or isolates a volatile boundary.
- Reuse repository conventions before inventing a new pattern.
- Handle plausible failures at the system boundary. Do not defend against states that the surrounding system makes impossible.
- If the solution is much larger than the problem suggests, pause and look for a simpler design.

Prefer code that a maintainer can understand locally over code optimized for hypothetical future needs.

## 3. Make a Surgical Change

Keep every changed line traceable to the requested outcome or its verification.

- Inspect before editing and match the existing style.
- Change only the files and lines required by the implementation.
- Avoid drive-by refactors, formatting, renames, comment rewrites, and dependency upgrades.
- Preserve unfamiliar code unless the task requires changing it.
- Remove imports, variables, functions, or tests made obsolete by the current change.
- Mention unrelated problems instead of fixing them without authorization.

Before finishing, inspect the diff and remove accidental or speculative changes.

## 4. Verify the Outcome

Use the cheapest reliable evidence first, then expand in proportion to risk.

1. Run the narrowest test, type check, lint check, build, or reproduction that proves the change.
2. Add or update a regression test when behavior changes or a bug is fixed.
3. Run broader checks when the change touches shared code, public interfaces, persistence, security, or build configuration.
4. Read the final diff for scope, clarity, and unintended behavior.
5. Report what passed, what was not run, and any remaining uncertainty.

Do not claim success from code inspection alone when an executable check is available.

## Completion Gate

Finish only when all applicable answers are yes:

- Are consequential assumptions explicit or resolved?
- Is this the simplest complete solution?
- Can every changed line be connected to the request?
- Did the change clean up only the artifacts it created?
- Do the verification results demonstrate the stated success criteria?
