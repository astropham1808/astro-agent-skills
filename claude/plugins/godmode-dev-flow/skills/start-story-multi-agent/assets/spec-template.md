# <ID> - <Story title>

Owner: claude-code | codex        Size: S/M/L        Base: <base branch>

## Context
<2-3 lines pulled from the source of truth. No more.>

## Scope
- In: <what this story touches>
- Out: <explicitly not this story>

## Done when (every line must be a runnable command)
- [ ] <unit-or-integration-test-command> -> pass
- [ ] <typecheck-or-lint-command> -> pass
- [ ] artifacts/<ID>.png exists and is human-reviewed (when the story has a visual claim)
- [ ] scripts/verify-project.sh -> exit 0

## Notes for the reviewer
Focus areas: <boundary, invariant, compatibility, security, or performance risk>
