# Existing project scan

## Safety

Begin read-only. Do not install, format, generate, migrate, modify Git state, or run commands that can contact production. Read applicable repository instructions first. Preserve uncommitted work.

## Inventory

Inspect the narrowest useful evidence:

1. Repository instructions and contributor docs.
2. Manifests, lockfiles, runtime versions, and workspace configuration.
3. Source directories and architectural boundaries.
4. Tests, fixtures, coverage policy, and canonical verification commands.
5. CI/CD, release, deployment, environments, and secrets handling.
6. Database schemas, migrations, queues, caches, and external services.
7. API schemas, clients, authentication, authorization, and error contracts.
8. UI system, accessibility, content, responsive behavior, and visual tests.
9. Logging, metrics, tracing, incident handling, and performance budgets.
10. Backlog, roadmap, issue IDs, ADRs, ownership, and agent workflow.

Use fast file discovery and targeted reads. Do not read generated output, dependency trees, or the entire repository without a reason.

## Gap analysis

Classify each area:

- `Adopt`: sufficient and internally consistent.
- `Adapt`: useful but needs a scoped correction.
- `Add`: missing and valuable for the stated goal.
- `Avoid`: generic setup would conflict with the project.
- `Unknown`: evidence is insufficient or a human decision is required.

Report:

| Area | Classification | Evidence | Impact | Smallest proposed action |
| --- | --- | --- | --- | --- |

Prioritize correctness and safety gaps before documentation polish. Distinguish repository facts from recommendations.

## Reconciliation

After approval:

- update existing files rather than creating duplicates;
- preserve terminology, IDs, commands, and architecture;
- add links between existing sources of truth;
- avoid replacing a specialized verifier with a generic one;
- create templates only where no authoritative equivalent exists;
- validate changed artifacts and report intentional omissions.
