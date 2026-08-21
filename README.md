# Farseer

An agentic skill system for autonomous development with Claude Code.

## Table of Contents

- [Overview](#overview)
- [Getting Started](#getting-started)
  - [Installation](#installation)
  - [Quick Start](#quick-start)
- [How It Works](#how-it-works)
  - [Four Phases](#four-phases)
  - [Pipeline](#pipeline)
  - [Dependency Graph](#dependency-graph)
  - [Parallel Execution](#parallel-execution)
  - [TDD Methodology](#tdd-methodology)
- [Reference](#reference)
  - [Files Created](#files-created)
  - [Task Format](#task-format)
  - [Skills](#skills)
  - [Outputs](#outputs)
- [Architecture](#architecture)
- [Design Principles](#design-principles)
- [License](#license)

## Overview

Farseer separates **planning** (human-in-the-loop) from **execution** (fully autonomous):

```text
Planning → Human + AI collaborate on ideas, requirements, and plan/ticket creation
Execution → Parallel TDD workers implement autonomously
```

Additional useful AI skills are included to enhance understanding, learning, and decision-making throughout the development process.

## Getting Started

### Installation

Add the marketplace, install, then reload:

```bash
/plugin marketplace add https://github.com/petemcw/farseer
/plugin install farseer@farseer
/reload-plugins
```

### Update

To update the Farseer plugin, run the following commands:

```bash
/plugin marketplace update farseer
/reload-plugins
```

### Quick Start

#### 1. Setup Project (one-time)

```bash
/farseer:repo-setup
```

Interactively configures your project:

- Auto-detects technology stack (Laravel, React, etc.)
- Asks about testing, linting, architecture, domain knowledge
- Creates `.farseer/` config directory

#### 2. Plan

##### Large Bouts of Work

Plan a new project or a chunk of work too big for one agent session as a shared map of decision tickets on your issue tracker, then resolve them one at a time until the path to the destination is clear.

Invoke the `/farseer:farseer` command to start the discovery process.

##### Discrete Features

Just describe what you want:

```text
"Help me build user authentication with JWT"
```

The `/farseer:planner` skill activates automatically to:

- **Discover & brainstorm** — explore the codebase and enumerate scope/assumption permutations a senior engineer would catch
- Create a `feature/{plan-name}` branch for the work
- Ask grounded clarifying questions
- Break down into tasks with dependencies
- Write requirements as test descriptions
- Create `.farseer/plans/user-auth/` with issues locally or pushed to your remote issue tracker
- Run **post-plan pipeline** agents (devil's advocate by default) to find gaps before execution

After planning completes, you'll be asked:

> Ready to begin autonomous implementation?
>
> 1. **Yes, start now** - I'll trigger `orchestrate` immediately
> 2. **No, I'll run it later** - Say "run the {plan-name} plan" anytime to start
>
> Optional, for large plans: set a goal first so execution completes unattended —
> `/goal the {plan-name} plan run reached a terminal state: orchestrate output ALL_TASKS_COMPLETE or TASKS_BLOCKED`

#### 3. Execute Autonomously

If you chose "later" or want to re-run, say:

```text
"Run the user-auth plan" or "Execute the plan"
```

The `/farseer:orchestrate` skill auto-triggers. It verifies you're on the correct `feature/{plan-name}` branch before starting.

Session persistence is native to Claude Code — no plugin required. Auto-compaction handles context limits, and all run state (task statuses, requirement checkboxes, retry counts) lives in the plan files, so an interrupted run resumes by re-running the plan. For large plans, you can optionally set a goal first so execution completes unattended with:

```bash
/goal the user-auth plan run reached a terminal state: orchestrate output ALL_TASKS_COMPLETE or TASKS_BLOCKED
```

After completion, you'll be prompted to push the branch (never done without your permission).

## How It Works

### Four Phases

| Phase           | Type        | What Happens                                                                  |
| --------------- | ----------- | ----------------------------------------------------------------------------- |
| Setup           | One-time    | Configure project for autonomous development                                  |
| Planning        | Interactive | Discover codebase, brainstorm scope, then define tasks with human guidance    |
| Post-Plan Hooks | Automated   | Agents enrolled at the `post-plan` hook review the plan                       |
| Execution       | Autonomous  | Parallel TDD implementation, with agents enrolled at the implementation hooks |

### Pipeline

The pipeline controls which agents run at fixed points in the plan/implementation flow. Farseer uses **convention over configuration**: there is no central registry. Each agent enrolls itself by declaring a `phase` in its own YAML frontmatter. If an agent declares a `phase`, it runs at that hook; if it has no `phase`, it never runs via a hook.

**Hook points:**

There are exactly **8** hook points where enrolled agents can run:

| Hook                  | Fires                                                     |
| --------------------- | --------------------------------------------------------- |
| `pre-plan`            | Before planning Discovery begins                          |
| `post-plan`           | After the plan is built and validated, before user review |
| `pre-implementation`  | Before the first implementation batch                     |
| `pre-batch`           | Before each batch of TDD workers is spawned               |
| `post-batch`          | After each batch of TDD workers completes                 |
| `post-implementation` | After all tasks complete                                  |
| `pre-commit`          | After the full test suite passes, before the commit       |
| `post-commit`         | After the commit, before the push/PR prompt               |

By default, only `devils-advocate` and `issue-creator` are enrolled (at `post-plan`). See **[HOOKS.md](./HOOKS.md)** for the authoritative reference — the full frontmatter schema, the deterministic discovery routine, and tie-break/ordering rules.

**Enrollment frontmatter:**

An agent enrolls by adding three keys to its frontmatter:

```yaml
---
name: devils-advocate
description: "..."
model: opus
tools: Read, Write, Edit, Glob, Grep
# --- hook enrollment ---
phase: post-plan   # one of the 8 hook points above
order: 10          # lower runs first within a hook; default 100
mode: single       # "single" | "batch"; default "single"
---
```

**Customizing the pipeline:**

Enable, add, remove, or reorder agents by editing frontmatter — never a central file.

- **Enable a built-in agent.** `standards-enforcer` ships with its enrollment commented out. Uncomment its `phase` (and optional `order` / `mode`) to turn it on:

  ```yaml
  ---
  name: standards-enforcer
  description: "..."
  model: opus
  tools: Read, Edit, Glob, Grep
  # To enable code-standards enforcement after implementation, uncomment:
  phase: post-implementation
  order: 50
  mode: batch
  ---
  ```

- **Add a custom gate.** Drop an agent file into your project's `.farseer/agents/` directory with a `phase`, and it is enrolled automatically:

  ```markdown
  ---
  name: doc-updater
  description: "Updates documentation when implementation changes."
  model: sonnet
  tools: Read, Edit, Glob, Grep
  phase: post-implementation
  order: 100
  mode: single
  ---

  You are a documentation updater. Your job is to...
  {define the agent's behavior, process, and output format}
  ```

- **Disable an agent.** Remove (or comment out) its `phase` key — there is no condition to toggle.

The agent's **filename** (without `.md`) should match its frontmatter `name`. Local agents in `.farseer/agents/` override plugin agents with the same `name` (the local file wins entirely) — the override is keyed on the frontmatter `name`, not the filename.

**Check what's actually enrolled.** After editing frontmatter, run the discovery script to confirm it took effect. This is the first thing to try when an agent doesn't fire:

```bash
~/.claude/plugins/marketplaces/farseer/hooks/discover-hooks.sh
```

```text
# hook: pre-plan
  (empty — no agents enrolled at this hook)

# hook: post-plan
  order=10    name=devils-advocate                          mode=single
...
```

Add `--hook=post-plan` for one hook, or `--json` for machine-readable output. Farseer's planning skills run this exact script rather than enumerating agent files themselves, so what it prints is what will run.

A **non-zero exit means discovery genuinely failed** — it is not the same as a hook being empty. Exit `3` means an agent file declares an invalid `phase` or `mode` (the message names the file and the fix); exit `4` means enrollment changed partway through a run. Both halt Farseer deliberately, rather than quietly running a different pipeline than you configured.

### Dependency Graph

After generating a plan, Farseer visualizes the task dependency graph so you can verify parallelism and ordering before execution:

```text
001 ─┬─► 002 ─┬─► 005
     │        │
     └─► 003 ─┘
     │
     └─► 004 ────► 006
```

This tells the orchestrator which tasks can run in parallel and which must wait. In this example:

- **Batch 1:** Task 001 (no dependencies)
- **Batch 2:** Tasks 002, 003, 004 (all depend only on 001)
- **Batch 3:** Tasks 005, 006 (005 depends on 002+003; 006 depends on 004)

### Parallel Execution

Independent tasks within each batch run simultaneously:

```text
Batch 1: Task 001 (no deps)          → 1 worker
Batch 2: Tasks 002, 003, 004         → 3 parallel workers
Batch 3: Tasks 005, 006              → 2 parallel workers
```

100 tasks might complete in 5-10 batches instead of 100 sequential runs.

### TDD Methodology

Each task follows strict Red → Green → Refactor:

1. Write failing test for one requirement
2. Write minimum code to pass
3. Refactor while tests stay green
4. Repeat for next requirement
5. Commit when task complete

## Reference

### Files Created

#### Project Config (`.farseer/`)

| File                | Purpose                               |
| ------------------- | ------------------------------------- |
| `architecture.md`   | Directory structure, patterns         |
| `code-standards.md` | Linting, formatting rules             |
| `domain.md`         | Project vocabulary and business rules |
| `issue-labels.md`   | Labels used for issues and PRs        |
| `issue-tracker.md`  | Issue tracking configuration          |
| `testing.md`        | Test commands, coverage requirements  |

#### Plans (`.farseer/plans/{name}/`)

| File                      | Purpose                       |
| ------------------------- | ----------------------------- |
| `_plan.md`                | Plan overview, task table     |
| `./issues/001-{task}.md`  | First task with requirements  |
| `./issues/002-{task}.md`  | Second task                   |
| ...                       | More tasks                    |

### Task Format

```markdown
# Task 001: Create User Model

**Status**: pending
**Depends on**: none
**Retry count**: 0

## Description

Create the User model with authentication fields.

## Context

<issue context>

## Requirements (Test Descriptions)

- [ ] `it creates a user with valid email and password`
- [ ] `it hashes the password before storing`
- [ ] `it validates email uniqueness`

## Acceptance Criteria

<criteria>

## Implementation Notes

<notes>
```

Requirements become test names directly.

### Skills

All skills can be invoked directly with `/farseer:skill-name` or triggered automatically by Claude when your request matches their description.

| Skill                           | Invocation                                | Auto-triggers                                                                                         | Description                                                             |
| ------------------------------- | ----------------------------------------- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `architecture-decision-records` | `/farseer:architecture-decision-records`  | Yes - "Create ADR", "Record architecture decision", "Log decision"                                    | Capture architectural decisions made during coding sessions             |
| `but-how`                       | `/farseer:but-how`                        | No                                                                                                    | Use for 'how does X work'                                               |
| `but-why`                       | `/farseer:but-why`                        | No                                                                                                    | Use for 'why does X work this way'                                      |
| `deslop`                        | `/farseer:deslop`                         | Yes                                                                                                   | Cut out AI tells from any writing                                       |
| `domain-modeling`               | `/farseer:domain-modeling`                | Yes                                                                                                   | Build and sharpen a project's domain model                              |
| `farseer`                       | `/farseer:farseer`                        | No                                                                                                    | Plan a chunk of work too big for one agent session                      |
| `git-guardrails`                | `/farseer:git-guardrails`                 | Yes                                                                                                   | Set up Claude Code hooks to block dangerous Git commands                |
| `interviewer`                   | `/farseer:interviewer`                    | Yes                                                                                                   | Question the user relentlessly                                          |
| `orchestrate`                   | `/farseer:orchestrate [plan-name]`        | Yes - "Run the plan", "Execute", "Start implementation"                                               | Parallel TDD execution                                                  |
| `planner`                       | `/farseer:planner [description]`          | Yes - "Build a", "Let's start building", "I want an app that", "Help me implement", etc.              | Interactive planning with codebase discovery and grounded clarification |
| `repo-setup`                    | `/farseer:repo-setup`                     | No                                                                                                    | Configure project (one-time)                                            |
| `teach`                         | `/farseer:teach`                          | No                                                                                                    | Teach the user about a specific topic                                   |
| `triage`                        | `/farseer:triage`                         | No                                                                                                    | Move issues through a state machine of issue roles                      |
| `understand`                    | `/farseer:understand`                     | No                                                                                                    | Explain a body of work plainly so a person actually understands it      |

### Outputs

| Output                      | Meaning                         |
| --------------------------- | ------------------------------- |
| `ALL_TASKS_COMPLETE`        | Plan finished successfully      |
| `TASKS_BLOCKED: [003, 007]` | Some tasks failed after retries |

## Architecture

```bash
farseer/
├── .claude-plugin/
│   ├── marketplace.json                    # Marketplace manifest
│   └── plugin.json                         # Plugin manifest
├── .claude/
│   └── CLAUDE.md                           # Farseer's own project config (not shipped to users)
├── agents/
│   ├── devils-advocate.md                  # Plan reviewer - finds gaps before execution (opus)
│   ├── issue-creator.md                    # Creates issues based on plan gaps (sonnet)
│   ├── standards-enforcer.md               # Code standards enforcement (opus)
│   └── tdd-worker.md                       # TDD implementation worker (sonnet)
├── hooks/
│   ├── discover-hooks.sh*                  # Deterministic hook-agent discovery (see HOOKS.md)
│   ├── resolve-plans-dir.sh*
│   └── resolve-project-dir.sh*
├── skills/
│   ├── architecture-decision-records/
│   ├── but-how/
│   ├── but-why/
│   ├── deslop/
│   ├── domain-modeling/
│   ├── farseer/
│   ├── git-guardrails/
│   ├── interviewer/
│   ├── orchestrate/
│   ├── planner/
│   ├── repo-setup/
│   ├── teach/
│   ├── triage/
│   └── understand/
├── HOOKS.md                                # Authoritative hook/frontmatter reference
├── LICENSE
└── README.md
```

The `CLAUDE.md` template that `/farseer:repo-setup` generates for **your** project lives inline in `skills/repo-setup/SKILL.md` — `.claude/CLAUDE.md` above is this repo's own config and has no effect on what users get.

## Design Principles

1. **Pure TDD** - No Gherkin/BDD, requirements map directly to test names
2. **Parallel by default** - Auto-detect independent tasks, maximize concurrency
3. **100% portable** - the generated CLAUDE.md is identical across all projects
4. **Explicit dependencies** - Tasks declare what they depend on
5. **Fail gracefully** - Retry 3x, then block and continue with other tasks

## Credits

- Inspired by [Mark Shust's HCF](https://github.com/markshust/hcf)
- Inspired by [Matt Pocock's Skills](https://github.com/mattpocock/skills)
- Inspired by [Lauren Tan's pstack](https://github.com/cursor/plugins/tree/main/pstack)

## License

Farseer is open-source software licensed under the [MIT License](LICENSE).
