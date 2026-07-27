# Classification and discovery

## Classification schema

Record:

```text
Mode:
Product category:
Lifecycle:
Primary users:
Problem:
Surfaces:
Platforms:
Revenue or operating model:
Source of truth:
Artifact language:
Delivery model:
Constraints:
Unknowns:
```

Use `greenfield` when no meaningful implementation or authoritative project structure exists. Use `existing` when code, conventions, deployment, or users already constrain decisions.

Classify products by their primary contract:

| Type | Primary contract |
| --- | --- |
| Web app | Browser interaction and responsive UI |
| SaaS | Hosted product, accounts, tenancy, billing, and operations |
| Desktop | Installed native shell and OS integration |
| Mobile | Device interaction, permissions, stores, and offline state |
| Backend/API | Network schemas, reliability, security, and operations |
| Developer tool | Integration with developer workflows and local systems |
| CLI | Commands, streams, exit codes, and automation |
| SDK/library | Stable public API, packaging, and compatibility |
| Data/AI | Data and evaluation contracts, privacy, cost, and model behavior |
| Browser extension | Browser permissions, content scripts, stores, and updates |
| Hybrid | Multiple first-class surfaces with explicit shared boundaries |

Do not classify from technology alone. React can serve SaaS, desktop, mobile, or an internal tool.

## Minimum discovery questions

Ask only unanswered questions:

1. Who experiences the problem, and what do they do today?
2. What observable outcome makes the product valuable?
3. What is the smallest usable release?
4. What is explicitly outside the first release?
5. Which platforms, environments, integrations, and data are mandatory?
6. What failures would be unacceptable?
7. Which decisions are fixed, and which require research or a spike?
8. How will success be measured?

For existing projects, prefer repository evidence and ask the user only about conflicts, missing business context, and authority to change established conventions.

## Confidence rules

Label important claims:

- `Confirmed`: directly stated by the user or authoritative source.
- `Observed`: supported by repository evidence.
- `Inferred`: best explanation of available evidence.
- `Unknown`: requires a decision or external evidence.

Never silently turn an inference into a requirement.
