# Issue Tracker: GitHub

Issues for this repo live as GitHub issues.

## Access

Use the `gh` CLI for all operations.

## Conventions

- **Issue titles** use the vocabulary in `.farseer/glossary.md`
- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Infer the repo from `git remote -v`; `gh` does this automatically when run inside a clone.

## Issue relationships

`gh` supports native blocked-by / blocking relationships as of **2.94.0** (check with `gh --version`). Use these instead of writing `#N` references into the body. GitHub renders them as real dependencies, surfaces them in the issue sidebar, and can filter on them.

**The flag names differ between subcommands.** `create` takes a plural, comma-separated list; `edit` takes `--add-`/`--remove-` prefixes:

```bash
# at creation — comma-separated, no spaces
gh issue create --title "..." --body "..." --blocked-by 200,201 --blocking 300

# after the fact
gh issue edit 123 --add-blocked-by 200 --add-blocking 300,301
gh issue edit 123 --remove-blocked-by 200
```

Both accept issue numbers or full URLs.

**When creating a set of issues from a plan, create them in dependency order** — blockers first — so each `--blocked-by` can reference an issue number that already exists. Otherwise a second `gh issue edit` pass is needed to wire up relationships.

A plan's task dependencies map directly: task 005's `**Depends on**: 002, 003` becomes `--blocked-by <issue for 002>,<issue for 003>` on the issue for task 005.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Farseer Operations

Used by `/farseer:farseer`.

The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `farseer:map`, holding the Notes / Decisions-so-far / Fog body. `gh issue create --label farseer:map`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue (see **Make an issue a sub-issue of a parent**). Where sub-issues aren't enabled, add the child to a task list in the map body and put `Part of #<map>` at the top of the child body. Labels: `farseer:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: GitHub's **native issue dependencies**, the canonical, UI-visible representation. Add an edge with `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where `<blocker-db-id>` is the blocker's numeric **database id** (`gh api repos/<owner>/<repo>/issues/<n> --jq .id`, _not_ the `#number` or `node_id`). GitHub reports `issue_dependencies_summary.blocked_by` (open blockers only, the live gate). Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. A ticket is unblocked when every blocker is closed.
- **Frontier query**: list the map's open children (`gh issue list --state open`, scoped to the map's sub-issues / task list), drop any with an open blocker (`issue_dependencies_summary.blocked_by > 0`, or an open issue in the `Blocked by` line) or an assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me`, the session's first write.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append a context pointer (gist + link) to the map's Decisions-so-far.
