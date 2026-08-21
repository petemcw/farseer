# Domain Context

Vocabulary and business rules for this project.

Use this language in class names, method names, test names, and issue titles. When a term here conflicts with a generic term, the domain term wins in naming.

If any of the mentioned files do not exist, **proceed silently**. Do not flag their absence; don't suggest creating them.

## Where domain knowledge lives

| Source          | Contents                             |
| --------------- | ------------------------------------ |
| `AGENTS.md`     | Full coding conventions              |
| `.farseer/adr/` | Architecture Decision Records (ADRs) |
| `docs/`         | Project-specific documentation       |

## Core Vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined here. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap and you should propose a new glossary entry.

### Glossary

## Business-Critical Paths

Changes here carry the highest test and review burden:

## Architecture Decision Records

Before changing anything in the business-critical list, check `.farseer/adr/` for a decision covering that area.

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders), but worth reopening because…_
