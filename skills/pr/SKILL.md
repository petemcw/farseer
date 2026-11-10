---
name: pr
description: "Use when writing a PR body."
---

Use this template for writing the PR body:

```markdown
<!--
  PR title = the squash commit on master, so write it as a Conventional Commit:
  feat: …, fix: …, chore: …, refactor: …, test: …, docs: …
-->

## Summary

<!-- What changed and why, in a few sentences. -->

**Ticket:** <!-- Jira link for ABC-123 -->

[diagram, diff-sketch, or tree]

## Risk tier

<!-- Pick one. A reviewer can raise the tier, never lower it. -->

- [ ] **Tier 1 · Low**: copy, CSS, docs, tests only, config text
- [ ] **Tier 2 · Standard**: features, new modules, refactors, bug fixes
- [ ] **Tier 3 · High**: payment, checkout, pricing, tax, auth/ACL, schema or data patches, integrations that write data, deploy/hosting config, `composer.json` constraints

## AI assistance

- [ ] None
- [ ] Assisted: AI suggested or completed parts; I wrote or rewrote the rest
- [ ] Generated: most of the diff came from an agent

<!-- If generated, paste the approved plan or summarize the prompt/plan here. -->

## Evidence

- **Before:** [screenshot/output/failing test run]
  **After:** [screenshot/output/passing test run]

## How it was verified

**Preview:** <!-- Add the `preview` label for an Upsun preview; its URL appears as the "Preview environment" status. Otherwise "n/a". -->

<!-- Steps a reviewer can follow to see it work. -->

1.

## Deployment notes

<!-- Delete the lines that don't apply. "None" is a fine answer for most PRs. -->

- **Database:** <!-- schema changes, data patches, update hooks; do they reverse cleanly? -->
- **Config:** <!-- config import, env vars, secrets, cron, queues -->
- **After deploy:** <!-- cache flush, reindex, manual steps -->
- **Rollback:** <!-- Required for Tier 3. Reverting code doesn't undo a migration. -->

## Merge Danger

**Door:** [one-way or two-way]

[optional: description]

**Blast Radius:** [one-word description]

[optional: potential ramifications of merge]
```

## Sections

Skip all preambles and keep prose brief. Use the user's domain language from `.farseer/glossary.md`.

### Summary

Pick the smallest view that makes the key point clear.

- Show logic or an algorithm as pseudocode:

```text
on(save)
  if content is unchanged
    return cached result
  write new content
  return fresh result
```

- Show runtime control flow as a call tree:

```text
submitForm
  createSession
    persistPrompt
    launchAgent
  navigateToSession
```

- Show UI structure as a component tree, including state and module boundaries that matter:

```text
<SessionPage> (apps/example/src/routes/session.tsx)
  useSessionEvents()
  <SessionToolbar>
    <RunSkillButton> (packages/ui)
```

- Show file responsibility or a broad refactor as a shallow file tree:

```text
src/
├── commands/       # parses user actions
├── sessions/       # owns session state
└── transport/      # sends API requests
```

- Show component interaction, control flow, or data flow with Mermaid:

```mermaid
sequenceDiagram
    participant User
    participant UI
    participant Daemon
    User->>UI: choose command
    UI->>Daemon: send expanded prompt
    Daemon-->>UI: stream result
```

- Use `diff` when the point is what changes and the surrounding shape already exists. Match the diff shape to the topic.

For a component change:

```diff
 <SessionPage>
   useSessionEvents()
   <SessionToolbar>
+    <RunSkillButton />
   <SessionTimeline>
+    <SkillResultCard />
```

For a file-layout change:

```diff
 src/
 ├── commands/
+│   └── show-me.ts       # expands the slash command
 ├── sessions/
-└── transport.ts
+└── transport/
+    ├── client.ts
+    └── stream.ts
```

For a call-tree or call-stack change:

```diff
 submitForm
   createSession
     persistPrompt
+    expandSkillMention
     launchAgent
-  navigateToSession
+  navigateToSession
+    subscribeToEvents
```

For a state or control-flow change:

```diff
 on(save)
-  write content
+  if content is unchanged
+    return cached result
+  write new content
+  invalidate cache
```

- Show the whole block when most of it is new, when omitted context would hide ownership or order, or when the user needs a copyable target shape:

```ts
function expandSkill(command: string): string {
  const skillName = command.slice(1);
  return `use the ${skillName} skill`;
}
```

#### Guidance

Place each visual next to the short text it supports. Keep only the calls, files, props, states, and boundaries needed to answer the user's current question or the options to resolve the current discussion point.

You may use one of these, you may use several, it is unlikely you will use all of them. Use your judgement and don't overwhelm the user.

### Evidence

Concrete evidence that the change works. Show a before and after.

Screenshots are S-tier - when the environment is set up for it and the change is visual.

Execution-based evidence is A-tier. Test results, console output. Show the exact test that now fails and passes, using pseudocode.

### Merge Danger

Describe whether it's a one-way or two-way door. You can walk back through two-way doors, but not one-way doors. A PR that is cheap to roll back is lower risk. Changes that involve destructive actions or hard-to-reverse decisions are one-way doors.

The blast radius is the potential impact or scope of the changes introduced by this PR. Consider all possibilities. Examples are layout shift, breakages for consumers, mobile responsiveness, etc.
