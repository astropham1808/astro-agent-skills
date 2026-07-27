# Delivery models

## Selection

Choose the smallest model that meets the risk and throughput needs.

### Single-agent

Use for small, tightly coupled, exploratory, or poorly specified work. It has low coordination cost and no independent review by default.

### Dual-agent

Use for one material story where an implementer and independent reviewer improve confidence. Run implementation first, then review. Keep one bounded fix pass and optional re-review.

### Multi-agent

Use when several ready stories can proceed independently and deterministic verification exists. Parallel activity without independent scope is not useful throughput.

## Multi-agent protocol

1. One story has one implementation owner.
2. One owner uses one branch and one worktree.
3. No concurrent writers share a worktree.
4. Reviewers inspect diffs and relevant invariants without modifying the owner's worktree.
5. Verifiers run acceptance checks and report evidence.
6. Dependencies form an explicit execution order.
7. Remote tickets are materialized locally once per story.
8. Agent-to-agent review loops are bounded.
9. PR creation, landing, destructive Git actions, and merge remain human gates.

Recommended roles:

| Role | Responsibility |
| --- | --- |
| Coordinator | Classify, decompose, order dependencies, and assign owners |
| Implementer | Own the story worktree, code, tests, and scoped commits |
| Reviewer | Inspect the branch independently and report actionable findings |
| Verifier | Run commands and check acceptance artifacts |
| Human | Approve product decisions, external actions, and merge |

## Readiness test

Use multi-agent delivery only when:

- at least two stories are ready and independent;
- ownership boundaries are clear;
- interfaces are stable enough for parallel work;
- tests or artifact checks can detect regressions;
- review and integration capacity will not become the immediate bottleneck.

Otherwise prefer sequential or dual-agent delivery.
