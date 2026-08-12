# Artifact contracts

## Product profile

Keep classification, lifecycle, users, surfaces, sources, constraints, delivery model, and unresolved decisions in one short document.

## Product Plan

Cover:

1. Vision and problem.
2. Target users and jobs.
3. Market or alternative analysis when relevant.
4. Differentiators and non-goals.
5. Product principles.
6. Technical research and key decisions.
7. Roadmap and release gates.
8. Success metrics.
9. Risks and mitigations.
10. Open questions.

Separate evidence, decisions, and assumptions. Add citations for external research.

## Design Spec

Create only for user-facing surfaces. Define:

- design direction and accessibility;
- tokens and platform conventions;
- information architecture;
- key screens or interaction states;
- component inventory;
- input and keyboard behavior where relevant;
- content tone;
- loading, empty, error, offline, permission, and destructive states;
- responsive or platform-specific behavior;
- visual verification artifacts.

Do not place implementation-specific constants in prose when a design-token source should own them.

## Backlog

Group stories by capability or epic. Each story needs:

- stable ID;
- outcome-oriented title;
- priority and size;
- lifecycle status;
- observable acceptance criteria;
- dependencies;
- source or decision links.

Avoid stories that mix independent owners or cannot be verified. A story is ready only when its scope, exclusions, dependencies, and acceptance criteria are clear.

## Engineering Guide

Define:

- repository bootstrap;
- stack constraints;
- architecture map;
- canonical commands;
- testing and fixture strategy;
- security and safety rules;
- performance budgets;
- release and platform gates;
- milestone prompts;
- reusable story prompt;
- definition of done.

## Repository instructions

Keep `AGENTS.md` concise and operational. Include only rules that affect agent behavior: required reading, commands, architecture, editing boundaries, safety, verification, source-of-truth rules, agent ownership, and human gates.

## Story spec

Materialize a ticket before implementation:

```text
ID and title
Source
Owner, size, and base
Context
Scope in
Scope out
Constraints
Acceptance criteria mapped to commands or artifacts
Dependencies
Review focus
Human gates
```

## Notes

Record implemented scope, exclusions, decisions, verification results, artifacts, remaining risks, and follow-up candidates. Do not use notes as a substitute for tests.

## Verification

Prefer a project-owned deterministic command that runs the relevant formatter, lint, typecheck, unit tests, integration tests, and build checks. Platform or visual claims need their own artifacts and human gates.
