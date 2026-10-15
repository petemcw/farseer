# Issue Tracker: Local Markdown

Issues for this repo live as markdown files in `.farseer/plans/{plan-name}/issues/`.

## Conventions

- One feature per directory: `.farseer/plans/{plan-name}/`
- The spec is `.farseer/plans/{plan-name}/_plan.md`
- Implementation issues are one file per issue at `.farseer/plans/{plan-name}/issues/{NNN}-{task-name}.md`, numbered from `01`, never a single-digit issue file
- Triage state is recorded as a `Status:` line near the top of each issue file (see `issue-labels.md` for the role strings)
- Comments and conversation history append to the bottom of the file under a `## Comments` heading
- **Issue titles** use the vocabulary in `.farseer/glossary.md`

## When a skill says "publish to the issue tracker"

Create a new file under `.farseer/plans/{plan-name}/issues/` (creating the directory if needed).

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.

## Farseer operations

Used by `/farseer:farseer`.

The **map** is a file with one **child** file per ticket.

- **Map**: `.farseer/scratch/<effort>/map.md` (the Notes / Decisions-so-far / Fog body).
- **Child ticket**: `.farseer/scratch/<effort>/issues/NN-<slug>.md`, numbered from `01`, with the question in the body. A `Type:` line records the ticket type (`research`/`prototype`/`grilling`/`task`); a `Status:` line records `claimed`/`resolved`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `resolved`.
- **Frontier**: scan `.farseer/scratch/<effort>/issues/` for files that are open, unblocked, and unclaimed; first by number wins.
- **Claim**: set `Status: claimed` and save before any work.
- **Resolve**: append the answer under an `## Answer` heading, set `Status: resolved`, then append a context pointer (gist + link) to the map's Decisions-so-far in `map.md`.
