# <ID> - <Story title>

Owner: claude | codex     Size: S/M/L     Branch: `<owner>/<ID>`     Base: main

## Context
<2-3 lines pulled from the source of truth. No more. This file is the contract;
nobody re-queries the backlog after it exists.>

## Scope
- In: <what this story touches>
- Out: <explicitly not this story>

## Exclusive resources
<Anything from EXCLUSIVE in .agentflow.conf this story needs, or "none".
Claim it before touching it: `scripts/claim.sh take <resource> <ID>`.>

## Done when  (every line must be a runnable command)
- [ ] `<test command scoped to this story>` -> green
- [ ] `artifacts/<ID>.png` exists and a human has looked at it   <UI stories only>
- [ ] `scripts/verify.sh` -> exit 0

## Notes for the reviewer
Focus areas: <the two or three places a wrong answer here would be quiet and
expensive. If this story touches a RISKY_PATHS entry, say why.>
