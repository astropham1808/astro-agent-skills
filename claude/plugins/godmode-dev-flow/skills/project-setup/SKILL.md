---
name: project-setup
description: Classify, plan, reconcile, and bootstrap software product repositories. Use this skill when starting a greenfield web, SaaS, desktop, mobile, API, CLI, SDK, developer-tool, data, AI, browser-extension, or hybrid product; when scanning an existing repository before adopting it; or when creating or repairing product plans, design specs, backlogs, engineering guides, repository instructions, story templates, verification gates, and single, dual, or multi-agent delivery protocols. Also use when the user says "plan trước khi code", "set up project", "tạo backlog", "bootstrap repo", or points at an empty repo and asks what to do first. Consult this before writing implementation code for a new project.
---

# Project Setup

Set up a software product from evidence, explicit decisions, and human approval gates. Support two modes:

- `greenfield`: create a product and engineering foundation before implementation.
- `existing`: scan and reconcile an existing repository without overwriting its conventions.

Do not apply this skill to non-software projects.

## Start with classification

Ask only questions that cannot be answered from local evidence. Establish:

1. Mode: `greenfield` or `existing`.
2. Product type: web app, SaaS, desktop, mobile, backend/API, developer tool, CLI, SDK/library, data/AI, browser extension, or hybrid.
3. Lifecycle: prototype, MVP, growth, mature, or legacy modernization.
4. Surfaces: UI clients, API, workers, integrations, deployment targets, and supported platforms.
5. Source of truth: local request, Notion, issue tracker, existing documents, or a combination.
6. Artifact language.
7. Delivery model: single-agent, dual-agent, or multi-agent.

Read [references/classification-and-discovery.md](references/classification-and-discovery.md) when requirements are incomplete or product type is ambiguous.

Persist the result in `docs/PROJECT_PROFILE.md`. Treat this classification as provisional until the user approves it.

## Choose the workflow

### Greenfield

1. Run focused discovery and identify assumptions.
2. Research unstable or high-cost decisions using primary sources.
3. Draft the project profile and Product Plan.
4. Add a conditional Design Spec only when the product has a user interface.
5. Define architecture boundaries, technical risks, security constraints, performance budgets, and measurable success criteria.
6. Create an epic-based backlog with observable acceptance criteria and dependencies.
7. Create the Engineering Guide, repository instructions, story spec template, notes template, and verification contract.
8. Present the plan and open decisions. Wait for approval.
9. Bootstrap repository files only after approval.
10. Do not initialize Git, install dependencies, create remotes, push, or start implementation unless explicitly requested.

Read [references/artifact-contracts.md](references/artifact-contracts.md) before drafting artifacts.

### Existing project scan

1. Read every applicable `CLAUDE.md`, `AGENTS.md`, and repository instruction before inspecting broadly.
2. Preserve the current branch, uncommitted changes, conventions, and generated files.
3. Inventory product docs, manifests, source layout, architecture, commands, tests, CI/CD, deployment, data, API contracts, security, observability, and release process.
4. Infer product type and lifecycle from evidence. Mark uncertainty instead of guessing.
5. Classify each setup area as `Adopt`, `Adapt`, `Add`, `Avoid`, or `Unknown`.
6. Produce a gap analysis with evidence, impact, and the smallest proposed change.
7. Wait for approval before creating or modifying repository files.
8. Add only missing artifacts. Reconcile existing files surgically and never replace them with generic templates.

Read [references/existing-project-scan.md](references/existing-project-scan.md) before scanning.

## Select conditional artifacts

Always consider:

- `docs/PROJECT_PROFILE.md`
- `docs/PRODUCT_PLAN.md`
- `docs/BACKLOG.md`
- `docs/ENGINEERING_GUIDE.md`
- `CLAUDE.md` (plus `AGENTS.md` when Codex also works the repository)
- `specs/_TEMPLATE.md`
- `notes/_TEMPLATE.md`
- a deterministic project verifier

Create `docs/DESIGN_SPEC.md` for products with a user interface. Tailor its concerns:

- Web/SaaS: responsive behavior, accessibility, browser support, SEO when relevant, authentication, and deployment.
- Desktop: native integration, platform conventions, installers, updates, filesystem access, and cross-platform verification.
- Mobile: platform conventions, permissions, offline behavior, app stores, and device testing.
- API/backend: omit UI design unless an admin surface exists; define schemas, versioning, authentication, rate limits, errors, and observability.
- CLI: define command grammar, exit codes, stdout/stderr, non-interactive behavior, and shell/platform compatibility.
- SDK/library: define public API, compatibility, packaging, examples, migration policy, and release guarantees.
- Data/AI: define data contracts, evaluations, latency, cost, privacy, failure modes, human control, and model/provider boundaries.
- Hybrid: combine only the relevant contracts and identify shared versus platform-specific layers.

Use the templates under `assets/` as starting points, not as authority over existing project evidence.

## Configure delivery

Read [references/delivery-models.md](references/delivery-models.md) before recommending an agent workflow.

Default to the smallest adequate model:

- Single-agent for small, coupled, exploratory work.
- Dual-agent for one important story requiring independent review.
- Multi-agent for multiple ready, independent stories with reliable verification.

For multi-agent delivery, keep one implementation owner, branch, and worktree per story. Reviewers and verifiers remain read-only unless ownership is explicitly transferred. Keep PR creation and merge as human gates.

When a remote source such as Notion is used, fetch the narrowest sufficient story context once, record its ID or URL in the local spec, and make the local spec the execution contract.

## Bootstrap safely

After approval, run:

~~~bash
python3 "${CLAUDE_SKILL_DIR}/scripts/bootstrap_project.py" \
  --target <repository> \
  --project-name "<name>" \
  --mode <greenfield|existing> \
  --product-type <type> \
  --design-spec <auto|yes|no> \
  --instructions <agents|claude|both> \
  --dry-run
~~~

`--instructions` picks the repository instruction file: `agents` writes
`AGENTS.md` (Codex, the default), `claude` writes `CLAUDE.md`, and `both` writes
`CLAUDE.md` plus an `AGENTS.md` symlink pointing at it so one set of rules serves
both agents. Use `both` when the project will run the dual-agent flow.

Review the dry-run. Run again without `--dry-run` only when the listed files are in scope. The script refuses to overwrite files.

Validate with:

~~~bash
python3 "${CLAUDE_SKILL_DIR}/scripts/validate_setup.py" --target <repository>
~~~

Validation accepts either instruction file. Treat it as a completeness check, not proof that product decisions are correct.

## Completion contract

Return:

- mode, product type, lifecycle, surfaces, and source of truth;
- artifacts adopted, adapted, added, intentionally omitted, or still unknown;
- key product and technical decisions;
- backlog shape and dependency risks;
- chosen delivery model and ownership rules;
- exact verification commands;
- unresolved human gates;
- files created or modified.

Do not claim setup is complete while required decisions remain hidden, validation failed, or the user has not approved material assumptions.

## Related

Hand the resulting backlog to `start-story-multi-agent` for story delivery, and to
`close-story` for cleanup after each merge.
