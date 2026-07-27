# <ID> — <Story title>

Owner: claude-code | codex        Size: S/M/L        Base: main (or <ID> if dependent)

## Context
<2-3 lines pulled from the source of truth. No more.>

## Scope
- In: <what this story touches>
- Out: <explicitly not this story>

## Done when  (every line must be a runnable command)
- [ ] `cargo test <module>::` -> green
- [ ] `npx playwright test tests/<ID>.spec.ts` -> pass
- [ ] `artifacts/<ID>.png` exists and human-reviewed
- [ ] `scripts/verify.sh` -> exit 0

## Notes for the reviewer
Focus areas: <e.g. Rust safety, 60fps budget, no unwrap in render path>
