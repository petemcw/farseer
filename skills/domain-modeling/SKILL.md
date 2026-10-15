---
name: domain-modeling
description: Build and sharpen a project's domain model. Use when discussing codebase terminology or writing or editing a `glossary.md`.
---

# Domain modeling

Build and sharpen the project's domain model as you design. This is the active discipline: challenge terms, invent edge-case scenarios, and write each term into the glossary as soon as it settles. Merely reading `glossary.md` for vocabulary is not this skill. Any skill can do that in one line. This skill is for changing the model, not consuming it.

## File structure

```bash
├── .farseer/
│   └── glossary.md
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

Create `.farseer/glossary.md` lazily, only when you have something to write. If no `.farseer/glossary.md` exists, create one when the first term is resolved. ADRs, and the `.farseer/adr/` directory, belong to the `architecture-decision-records` skill.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `.farseer/glossary.md`, say so right away. "Your glossary defines 'cancellation' as X, but you seem to mean Y. Which is it?"

### Sharpen fuzzy language

When the user uses a vague or overloaded term, propose a precise canonical one. "You're saying 'account'. Do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships come up, test them with specific scenarios. Invent ones that probe edge cases and force the user to be precise about where one concept ends and the next begins.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, raise it. "Your code cancels entire Orders, but you just said partial cancellation is possible. Which is right?"

### Update glossary.md inline

When a term is resolved, update `.farseer/glossary.md` right there. Don't batch these up. Capture them as they happen. Use the format in [glossary-format.md](./references/glossary-format.md).

Keep `.farseer/glossary.md` free of implementation details. It is not a spec, a scratch pad, or a place to record implementation decisions. It is a glossary and nothing else.

### Hand decisions to the ADR skill

When a decision settles that might deserve an ADR, use the Skill tool with `architecture-decision-records`. It applies the test for whether an ADR is warranted and writes it. Do not create ADR files from this skill.
