# Issue Tracker: Local Markdown

Issues for this repo live as markdown files in `.farseer/plans/{plan-name}/issues/`.

## Conventions

- One feature per directory: `.farseer/plans/{plan-name}/`
- The spec is `.farseer/plans/{plan-name}/_plan.md`
- Implementation issues are one file per issue at `.farseer/plans/{plan-name}/issues/{NNN}-{task-name}.md`, numbered from `01`, never a single-digit issue file
- Triage state is recorded as a `Status:` line near the top of each issue file (see `issue-labels.md` for the role strings)
- Comments and conversation history append to the bottom of the file under a `## Comments` heading
- **Issue titles** use the vocabulary in `.farseer/domain.md`

## When a skill says "publish to the issue tracker"

Create a new file under `.farseer/plans/{plan-name}/issues/` (creating the directory if needed).

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.
