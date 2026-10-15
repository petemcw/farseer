---
name: orchestrate
description: Execute implementation plans with parallel TDD workers. Use when ready to run, execute, or start a plan. Triggers on "run the plan", "execute the plan", "implement the plan", "start the plan", "start implementation", "orchestrate", "begin autonomous execution". Requires a plan created by `/farseer:planner`.
argument-hint: "[plan-name]"
---

# Orchestrate

Execute all tasks in a plan using parallel TDD workers. Fully autonomous after invocation.

## Usage

```bash
orchestrate {plan-name}
```

Example: `orchestrate user-auth`

## Prerequisites

**First, resolve the plans directory and the project root,** once each. The plans directory is `.farseer/plans` unless the project overrides it in `.farseer/config.json`. Both scripts print an absolute path resolved from the project root, so the result does not depend on the working directory:

```bash
"{skill-base-dir}/../../hooks/resolve-plans-dir.sh"
"{skill-base-dir}/../../hooks/resolve-project-dir.sh"
```

**Shell variables do not survive between Bash calls.** Every `$PLANS_DIR` and `$PROJECT_DIR` below stands for the path these scripts printed: write that literal path, quoted, into each later command. Never run a command with an unset `$PLANS_DIR`. An empty value turns `"$PLANS_DIR/{plan-name}"` into `/{plan-name}` and `git reset -- "$PLANS_DIR"` into an error.

**Never substitute a hand-written `jq` line or a literal `.farseer/plans`.** A non-zero exit means the project root or the configured value is unusable; surface the script's stderr verbatim and stop. Quote every path, since a configured directory may contain spaces.

Then:

1. Plan must exist at `$PLANS_DIR/{plan-name}/`
2. Project must be configured (`.farseer/testing.md` exists)
3. Plan status must be `ready` or `in_progress`

Check prerequisites:

```bash
ls "$PLANS_DIR/{plan-name}/_plan.md" "$PROJECT_DIR/.farseer/testing.md"
```

If not found, output error and stop.

4. Must be on the correct feature branch

Verify the current branch matches `feature/{plan-name}`:

```bash
git branch --show-current
```

If the current branch is not `feature/{plan-name}`:

- Output an error explaining which branch is expected
- Ask the user if they'd like to check out `feature/{plan-name}`
- Do NOT proceed until on the correct branch

## Project Configuration

The orchestrator does not load `testing.md` or `code-standards.md` up front. It reads `testing.md` at [Step 4a](#step-4a-end-of-run-hooks-post-implementation--tests--commit), when it needs the full-suite command. Subagents read the rules files on their own from the [Project Rules](#project-rules) list.

### Project Rules

Build the rules file list once, before the first spawn. Each entry is an absolute path under `$PROJECT_DIR`, included **only if the file exists**:

```bash
for f in testing.md code-standards.md; do
  if [ -f "$PROJECT_DIR/.farseer/$f" ]; then printf '%s\n' "$PROJECT_DIR/.farseer/$f"; fi
done
```

Every subagent prompt carries this list under a `## Project Rules` heading, and the subagent reads each file itself. **Never paste or summarize the files' contents into a prompt.** A pasted copy is where paraphrase drift creeps in, and the subagent can read the original. Pass the concrete paths, not `$PROJECT_DIR`. As with `## Task File Path`, one resolver runs in this skill and every subagent gets a finished path.

## Execution Algorithm

### Step 0: Suggest Unattended Completion via /goal

Claude Code's built-in `/goal` command keeps a session working toward a verifiable end state — its evaluator runs after each turn and pushes execution to continue until the condition is met. Only the user can set a goal (`/goal` is a user-typed command and cannot be invoked from a skill), so surface a command tip the user can copy-paste and continue immediately. This is informational, never a gate. Do not wait for a response.

Display:

```text
Tip: for large plans, you can keep this run going unattended with Claude Code's
built-in /goal command (interrupt me now to set it, or set it before a future run):

  /goal the {plan-name} plan run reached a terminal state: /farseer:orchestrate output ALL_TASKS_COMPLETE or TASKS_BLOCKED

Either way, an interrupted run resumes from disk. Just re-run /farseer:orchestrate {plan-name}.
```

The suggested condition deliberately names **both** terminal outputs. A goal phrased as only `ALL_TASKS_COMPLETE` leaves the evaluator demanding more turns after a legitimately blocked run, when the correct behavior is to stop and report the blockage.

### Step 1: Load Plan Context

Read plan files:

- `$PLANS_DIR/{plan-name}/_plan.md` - Plan overview
- `$PLANS_DIR/{plan-name}/issues/*.md` - All task files

Build the [Project Rules](#project-rules) list now.

Parse each task file to extract:

- Task number (from filename)
- Status (pending | in_progress | completed | blocked)
- Dependencies (from `Depends on` field)
- Requirements (checkboxes)
- Retry count

Build a dependency graph as a data structure.

### Step 2: Update Plan Status

If plan status is `ready`, change to `in_progress`:

- Edit `$PLANS_DIR/{plan-name}/_plan.md`
- Set `## Status` to `in_progress`

**Check the run fingerprint.** Every hook call reads `$PLANS_DIR/{plan-name}/.hook-fingerprint` and passes it as `--expect=` (see [Hook Discovery](#hook-discovery)), so agent files changing mid-run halt the orchestration rather than silently swapping the pipeline. If the file is **missing**, capture one now so a resumed run is covered too:

```bash
"{skill-base-dir}/../../hooks/discover-hooks.sh" --fingerprint > "$PLANS_DIR/{plan-name}/.hook-fingerprint"
```

If the file exists, leave it alone. A malformed one makes the script exit 2; stop and tell the user to delete the file to re-baseline. Never type a fingerprint value into a command, only the `cat` of the file.

### Step 2a: Pre-Implementation Hook

Run the `pre-implementation` hook **once**, after the status is set to `in_progress` and **before** the first batch is launched.

Resolve and run enrolled agents via the **HOOKS.md discovery routine** (see [Hook Discovery](#hook-discovery) below) with `HOOK = pre-implementation`. Pass each agent the project context as described in [Spawning hook agents](#spawning-hook-agents).

**Exit 0 with empty stdout** is an empty hook: return immediately, log nothing, do no work, and proceed to Step 3. **Any non-zero exit stops the run**; see [Hook Discovery](#hook-discovery) for the full result table.

### Step 3: Find Ready Tasks

Execution is a **rolling** loop, not a lockstep one. Each task starts as soon as its own dependencies are complete; it never waits for unrelated tasks that happened to start alongside its dependencies. Track a **running set** which are the tasks with a worker in flight in this session.

A task is **ready** when:

- Status is `pending` (an `in_progress` task from an interrupted run counts as pending. See [Task Already In Progress](#task-already-in-progress))
- ALL dependencies have status `completed`
- It is **not** in the running set

```text
ready_tasks = []
for each task in tasks (in task-number order):
    if task.status == "pending" and task not in running:
        if all(dep.status == "completed" for dep in task.dependencies):
            ready_tasks.append(task)
```

### Step 4: Check Termination Conditions

**All Complete:**

```text
if all(task.status == "completed" for task in tasks):
    Run Step 4a: End-of-Run Hooks (quality gates + commit sequence before final completion)
    STOP
```

**Blocked State:**

```text
if len(ready_tasks) == 0 and len(running) == 0:
    if any(task.status != "completed" for task in tasks):
        # Nothing can start and nothing is running: blocked tasks, or pending tasks that depend on them
        blocked_tasks = [t for t in tasks if t.status == "blocked"]
        Output: TASKS_BLOCKED: {list blocked task numbers and reasons}
        STOP
```

**Waiting:**

```text
if len(ready_tasks) == 0 and len(running) > 0:
    # Nothing new can start yet, but workers are in flight
    Go to Step 6 and wait for the next completion
```

## Hook Discovery

All hooks in this skill (`pre-implementation`, `pre-batch`, `post-batch`, `post-implementation`, `pre-commit`, `post-commit`) resolve their enrolled agents by running **`hooks/discover-hooks.sh`**, the single implementation of [HOOKS.md → Discovery Routine](../../HOOKS.md#discovery-routine). **Never enumerate agent files by hand and never write a glob loop to do it.**

For a given `HOOK`:

```bash
"{skill-base-dir}/../../hooks/discover-hooks.sh" --hook=<HOOK> --expect="$(cat "$PLANS_DIR/{plan-name}/.hook-fingerprint")"
```

`{skill-base-dir}` is the **`Base directory for this skill`** value stated when this skill loaded — it is given verbatim, so no path inference is needed. `${CLAUDE_PLUGIN_ROOT}` is **not** available in a skill's Bash calls. Write `$PLANS_DIR` as the literal resolved path (see [Prerequisites](#prerequisites)).

Then, by result:

- **Exit 0, empty stdout → empty hook.** Return immediately — no staging, no diffing, no spawns, and **no logging or narration**. "No narration" is literal and is the rule most often broken: do not name the hook, do not say it is empty/skipped, do not explain _why_ it is empty, and **do not say the discovery script returned no agents**. A filtered query prints zero bytes precisely so there is nothing to echo. An empty hook is **completely invisible** in the user-facing output. See [HOOKS.md → Empty-hook fast path](../../HOOKS.md#empty-hook-fast-path).
- **Exit 0, output → PRINT it verbatim** as the resolved order, then spawn.
- **Exit 1 or 2 → stop the run.** Surface stderr verbatim.
- **Exit 3 → stop the run.** An agent file declares an invalid `phase` or `mode`. Surface stderr verbatim; it names the file and the fix.
- **Exit 4 → halt Farseer.** Hook enrollment changed since this run started, so the remaining hooks would execute a different pipeline than the plan was reviewed against. Surface stderr verbatim. Stop launching (see [Stopping mid-run](#stopping-mid-run)) and do **not** commit.
- **Script missing or not executable → hard failure.** Say so and stop. There is no prose fallback; reconstructing the routine by hand is the failure this design exists to end.

**Only exit 0 with empty stdout is an empty hook.** Every other non-zero exit is an error to report loudly.

On a normal (exit 0, non-empty) result, spawn each agent per its **`mode` field** (`single` → one sub-agent for the whole plan; `batch` → split the relevant file list into batches of ~10 and spawn parallel sub-agents, one Agent call per batch, all in a single message). The spawn mode comes from the agent's `mode` frontmatter field, never from sniffing the agent body text.

### Spawning hook agents

Hook agents are spawned with the Agent tool, choosing `subagent_type` by the row's `origin`: `farseer:{agent-name}` for `origin=plugin`, `{agent-name}` for `origin=local` (see [Spawning](../../HOOKS.md#spawning) in `HOOKS.md`). Give each hook agent the [Project Rules](#project-rules) list. The agent reads the files itself, so do not paste their contents.

For a **`batch`** agent, send one prompt per batch:

```markdown
## Project Rules

Read every file below in full before reviewing:

{the Project Rules list, one absolute path per line}

## Files to Review

{list of files in this batch, one per line}
```

For a **`single`** agent, send one prompt covering the whole plan:

```markdown
## Plan Directory

{the concrete resolved path, e.g. /abs/project/.farseer/plans/{plan-name}}

## Project Rules

Read every file below in full before starting:

{the Project Rules list, one absolute path per line}

## Project Issue Tracking

{absolute path to $PROJECT_DIR/.farseer/issue-tracker.md, or "none" if it does not exist}

## Files to Review

{the changed-files list; omit this section at pre-implementation, where nothing has changed yet}
```

> If a hook agent needs project architecture, that is out of scope for this
> orchestrator — it does not load `<architecture>`. Do NOT fabricate an
> `## Project Architecture` paste here.

### Step 4a: End-of-Run Hooks (Post-Implementation → Tests → Commit)

When all tasks are complete, run the end-of-run hook sequence. The control flow is strictly:

**post-implementation → run full test suite → pre-commit → commit → post-commit**

> **CRITICAL INVARIANT: NOTHING is committed until AFTER the full test suite
> passes.** This ensures no broken code is ever committed. The `pre-commit` hook
> runs _after_ tests pass and _before_ the commit; `post-commit` runs _after_
> the commit and _before_ the push/PR prompt.

**1. Run the `post-implementation` hook:**

Resolve and run enrolled agents via the [Hook Discovery](#hook-discovery) routine with `HOOK = post-implementation`. Before spawning anything, **checkpoint the implementation** and compute the changed files for batch agents. This stages everything only to snapshot it as a tree object and read the list, then unstages; nothing is committed. The plans directory is left out, because plan files are working state, not code for agents to review.

```bash
git add -A && git reset -q -- "$PLANS_DIR" && git write-tree > "$PLANS_DIR/{plan-name}/.impl-tree" && git diff --name-only --cached; git reset -q
```

The `.impl-tree` file is what [Test-failure isolation](#test-failure-isolation) compares against. Write the checkpoint even when the hook turns out to be empty.

Then spawn the resolved agents per their `mode` (see [Spawning hook agents](#spawning-hook-agents)). **Exit 0 with empty stdout** is an empty hook: return immediately, no logging, no work, and proceed to step 2.

**Any non-zero exit stops the run** — see [Hook Discovery](#hook-discovery).

**2. After ALL post-implementation agents complete, run validation:**

This is the only full-suite run. Workers run scoped tests only, because they share one working tree. Read `$PROJECT_DIR/.farseer/testing.md` now for the command, then run it:

```bash
# Run full test suite
{parallel test command from testing.md}
```

> **CRITICAL: Nothing is committed until AFTER the full test suite passes.** This ensures no broken code is ever committed.

**3. On test failure** — isolate the cause (see [Test-failure isolation](#test-failure-isolation) below), then either commit the implementation only or output `TASKS_BLOCKED`.

**4. On tests passing — run the `pre-commit` hook:**

Resolve and run enrolled agents via [Hook Discovery](#hook-discovery) with `HOOK = pre-commit`. These run _after_ the suite passes and _before_ the commit.

**Exit 0 with empty stdout** is an empty hook (silent no-op);
**any non-zero exit stops the run before the commit** — see [Hook Discovery](#hook-discovery).

If agents are enrolled, snapshot the tree before spawning them, then compare after they finish:

```bash
git add -A && git reset -q -- "$PLANS_DIR" && git write-tree > "$PLANS_DIR/{plan-name}/.pre-commit-tree"; git reset -q
# ...pre-commit agents run...
git add -A && git reset -q -- "$PLANS_DIR" && git diff --quiet --cached "$(cat "$PLANS_DIR/{plan-name}/.pre-commit-tree")"; echo "diff_exit=$?"; git reset -q
```

`diff_exit=0` means the agents edited nothing: go to step 5. Otherwise their edits become part of this commit, so **re-run the full suite** first. If it fails, go to [Test-failure isolation](#test-failure-isolation). Its patch covers every hook edit since the checkpoint, pre-commit's included.

**5. Commit:**

First, update `_plan.md` status to `completed`. Then stage and commit the implementation in a **single commit**, leaving the plans directory out:

```bash
# 1. Update plan status (local working state — it is not committed)
# (edit $PLANS_DIR/{plan-name}/_plan.md — set Status to "completed")

# 2. Stage everything: implementation + hook agent fixes + plan files (including updated status)
git add -A "$PLANS_DIR/{plan-name}/"
git add -A
git reset -q -- "$PLANS_DIR"
git commit -m "feat({plan-name}): {plan title summary}"
```

> **IMPORTANT:** There must be exactly ONE commit here. **Never commit plan
> files.** Plans are ephemeral: once the work is committed, the code and its
> tests are the source of truth, and a plan kept in the repo goes stale
> alongside them. Unstaging `$PLANS_DIR` (rather than excluding it with a
> pathspec) works whether the directory is untracked, gitignored, or was
> committed by an older Farseer version.

**6. After the commit succeeds — run the `post-commit` hook:**

Resolve and run enrolled agents via [Hook Discovery](#hook-discovery) with
`HOOK = post-commit`. These run _after_ the commit and _before_ the push/PR
prompt (the [Output Summary](#output-summary) at the end of this skill).
**Exit 0 with empty stdout** is an empty hook (silent no-op); **any non-zero
exit is reported loudly** — see [Hook Discovery](#hook-discovery). The commit
has already happened, so report the failure rather than trying to undo it.

> **`post-commit` agents that produce uncommitted changes are REPORTED, not
> silently committed.** The commit above already happened; do not amend or
> create a second commit. Surface any working-tree changes a post-commit agent
> left behind so the user can decide what to do.

Output: `ALL_TASKS_COMPLETE`

#### Test-failure isolation

If the full test suite fails, isolate whether the **hook agents** (any `post-implementation` or `pre-commit` agent that edited files) broke things or the implementation itself did. Never use `git stash` here. Nothing is committed yet, so a stash takes the workers' edits along with the hooks', and dropping it destroys them.

Save every hook edit since the [checkpoint](#step-4a-end-of-run-hooks-post-implementation--tests--commit) as a patch:

```bash
git add -A && git reset -q -- "$PLANS_DIR" && git diff --binary --cached "$(cat "$PLANS_DIR/{plan-name}/.impl-tree")" > "$PLANS_DIR/{plan-name}/hook-changes.patch"; git reset -q
```

If the patch is empty, the hooks changed nothing and the failure is the implementation's: output `TASKS_BLOCKED` with the failing tests. Otherwise take the hook edits out and re-run the suite on the implementation alone:

```bash
git apply -R "$PLANS_DIR/{plan-name}/hook-changes.patch"
```

- **Implementation tests pass:** a hook agent broke something. Commit the implementation only (step 5), keep the patch file, and output:

  ```text
  ALL_TASKS_COMPLETE

  WARNING: A post-implementation or pre-commit hook agent broke tests. Implementation committed without hook changes; they are saved in {plan dir}/hook-changes.patch for review.
  ```

- **Implementation tests also fail:** a TDD worker produced broken code. Put the hook edits back with `git apply "$PLANS_DIR/{plan-name}/hook-changes.patch"` and output `TASKS_BLOCKED` with details.

### Step 5: Launch a Batch

A **batch** is the set of ready tasks launched together in one pass through this step. Batches still exist and still get the `pre-batch` and `post-batch` hooks; what changed is when they start. A batch launches the moment tasks become ready and capacity allows, so several batches can be in flight at once. Number batches sequentially from 1 for the run.

**Every ready task launches.** Farseer sets no concurrency limit of its own. Claude Code's limit is 20 running subagents per session by default, raised with the `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` environment variable. Over that limit a spawn fails rather than queues, which [At the subagent limit](#at-the-subagent-limit) below handles.

```text
if at_limit:
    # A spawn hit Claude Code's limit and no worker has finished since
    Go to Step 6 and wait for the next completion
batch = ready_tasks
```

**Pre-batch hook.** Before launching, run the `pre-batch` hook via the [Hook Discovery](#hook-discovery) routine with `HOOK = pre-batch`. Because this runs before **every** batch, honoring the **empty-hook fast no-op** is important: on **exit 0 with empty stdout**, return immediately — log nothing, do no work — so unconfigured runs add zero overhead. **Any non-zero exit stops launching** (see [Stopping mid-run](#stopping-mid-run)); checking per batch is also what makes drift (exit 4) surface promptly rather than at the end.

**Mark the batch.** Set each task's status to `in_progress` in its task file and in the task table in `_plan.md`, and add it to the running set.

**Launch.** Spawn one `tdd-worker` per task as a **background** subagent, all in a single message, and do **not** wait for them here:

```text
Use the Agent tool with subagent_type="farseer:tdd-worker", run in the background, for EACH task in the batch.
All Agent tool calls for the batch go in a SINGLE message.
```

#### At the subagent limit

A spawn that fails with `Concurrent subagent limit reached` never started, so it is not a failure of the task: set that task back to `pending`, remove it from the running set, and do **not** increment its retry count. Set `at_limit`, and do not retry the spawn. The next completion in Step 6 clears `at_limit` and frees a slot. If the running set is empty when this happens, no completion is coming to free a slot (the limit is taken by subagents outside this run): surface the error and stop (see [Stopping mid-run](#stopping-mid-run)).

Output one line, then continue to Step 6:

```
Batch {B} launched: tasks {list} (running {len(running)})
```

**Worker Prompt (pass to each tdd-worker):**

```markdown
## Task File Path

{the concrete resolved path, e.g. /abs/project/.farseer/plans/{plan-name}/issues/{task-file}.md}

## Project Rules

Read every file below in full before writing any code:

{the Project Rules list, one absolute path per line}

## Your Task

{contents of the task file}
```

The `tdd-worker` agent already has all TDD methodology and rules. The prompt points it at the project's rules files and gives it the task details. Do not paste the rules files' contents.

Pass the **concrete** path under `## Task File Path`, not the literal `$PLANS_DIR` — the worker marks checkboxes and appends implementation notes there, and it must never read `.farseer/config.json` or assume a default to find it. One resolver runs in this skill; every subagent is handed a finished path.

### Step 6: Collect One Result

Wait for the **next** worker to finish — the harness notifies you as each background subagent completes. Do not poll, do not sleep, and do not wait for the rest of its batch. Process that one result, remove the task from the running set, and clear `at_limit`:

**On TASK_COMPLETE:**

1. Verify all requirements are checked in task file
2. Set task status to `completed`
3. Update the task table in `_plan.md`

> **NOTE:** Do NOT commit here. All commits are deferred to Step 4a, after standards enforcement and the full test suite pass. This ensures no non-standard code is ever committed.

**On TASK_FAILED:**

1. Increment retry count in task file
2. If retry count >= 3:
   - Set status to `blocked`
   - Set blocked reason from error message
   - Update task table in `_plan.md`
3. If retry count < 3:
   - Set status back to `pending` (it is ready again on the next pass through Step 3)
   - Log the failure for visibility

**Post-batch hook.** If this result was the **last** outstanding task of its batch, run the `post-batch` hook for that batch via the [Hook Discovery](#hook-discovery) routine with `HOOK = post-batch`. Other batches may still be running, so the working tree can hold their unfinished edits; a `post-batch` agent should look only at its own batch's tasks. **Any non-zero exit stops launching** (see [Stopping mid-run](#stopping-mid-run)). Honor the **empty-hook fast no-op**: if no agents are enrolled, return immediately, log nothing, and do no work.

### Step 7: Report Progress

After each result, output one line:

```
Task {N} {complete | failed (retry {r}/3) | blocked}. Progress: {completed}/{total}, running {len(running)}, ready {len(ready_tasks)}
```

When a batch's last task finishes, also output:

```text
Batch {B} complete:
  Completed: {list of completed task numbers}
  Failed (will retry): {list of failed tasks with retry < 3}
  Blocked: {list of newly blocked tasks}
```

### Step 8: Continue Loop

Return to Step 3 after **every** result, so tasks unblocked by that completion launch immediately in a new batch while the others keep running.

Continue until:

- `ALL_TASKS_COMPLETE` - All tasks finished successfully
- `TASKS_BLOCKED: [list]` - No progress possible

### Stopping mid-run

When a hook or the subagent limit stops the run while workers are still in flight, launch nothing further, but keep collecting results (Step 6, without hooks) until the running set is empty, so every task file ends in an accurate state. Then surface the error and stop. Do **not** run Step 4a and do **not** commit.

## Handling Edge Cases

### Task Already In Progress

If a task has status `in_progress` at startup (from an interrupted previous run):

- Treat it as `pending` and include in ready check — no worker from this session is running it
- Tasks this session marked `in_progress` in Step 5 are in the running set and are never relaunched
- The worker will pick up where it left off based on [x] marks

### Partial Completion

If some requirements are already [x] in a task:

- Worker will skip those and continue with unchecked ones
- This enables resumption after interruption

### Dependency on Blocked Task

If task A depends on blocked task B:

- Task A can never become ready
- It should be reported in final TASKS_BLOCKED output

### Test Failures in Completed Requirements

If a previously passing test starts failing:

- Worker should report TASK_FAILED
- Investigation needed - likely a breaking change

## Session Persistence

Session persistence is native to Claude Code — no plugin is required:

- **Context limits are not a failure mode.** When the conversation grows long,
  auto-compaction summarizes it and execution continues.
- **All run state lives on disk.** Task statuses, requirement checkboxes, and
  retry counts are stored in the plan files, so re-running
  `/farseer:orchestrate {plan-name}` resumes exactly where a previous run stopped
  (see [Handling Edge Cases](#handling-edge-cases)).
- **Unattended completion is the user's opt-in** via the built-in `/goal`
  command (see Step 0). The orchestrator's terminal outputs are the goal's
  verifiable end states: `ALL_TASKS_COMPLETE` on success, `TASKS_BLOCKED: [...]`
  when no progress is possible. Both are terminal — a blocked run ends the goal
  too, rather than leaving it spinning.

## Output Summary

Final output should be one of:

**Success:**

```markdown
ALL_TASKS_COMPLETE

Plan: {plan-name}
Total tasks: {N}
All tests passing.
Commit: {short sha}

## Hook Agents

{one line per hook agent that ran: its name and the summary it returned, e.g. what code-reviewer changed or left alone. Omit this section if no hook agent ran.}

## What Changed

{Brief, high-level summary of what was built or changed. Write this as a bulleted list describing the user-visible outcomes, not implementation details. Derive this from the completed task titles and the plan objective. For example:}

- Added visitor name column to the detail table
- Linked visitor rows to their detail pages
- Reordered columns to match design spec
- Added sorting to all new columns
```

> **NOTE:** The "What Changed" section should read like release notes. Focus on outcomes,
> not internals. Pull from the plan's objective and completed task summaries.

After displaying the success output, prompt the user about pushing and creating a PR:

```markdown
Would you like to push this branch and create a pull request?

1. **Yes, push and create PR** - I'll push feature/{plan-name} and open a PR
2. **Just push** - I'll push the branch, you can create the PR later
3. **No thanks** - Keep everything local for now
```

**Never push or create a PR without the user's explicit permission.** Wait for their response before taking action. If they choose option 1, push and use `gh pr create` with a summary derived from the plan objective and "What Changed" section.

**Linking GitHub Issues:** Check `_plan.md` for the `## Related Issues` field. If it contains issue references (e.g., `Closes #18`), include them in the PR body so GitHub automatically links and closes the issues when the PR is merged. Place them at the end of the PR body, each on its own line.

**Plan cleanup:** End the success output by noting that the plan folder was not
committed and can be deleted once the branch is merged:
`Plan files in {plans dir}/{plan-name}/ were not committed — delete them once this work is merged.`
Never delete the folder yourself; the PR step above still reads `_plan.md`.

**Blocked:**

```markdown
TASKS_BLOCKED: [003, 007]

Plan: {plan-name}
Completed: {X}/{N}
Blocked tasks:

- 003: {blocked reason}
- 007: {blocked reason}

Manual intervention required for blocked tasks.
```

**Partial Progress (for visibility during execution):** the per-result and per-batch lines from [Step 7](#step-7-report-progress).

## Performance Expectations

Total time tracks the plan's **longest dependency chain**, not the sum of each batch's slowest task. A task never waits for unrelated work: if 002 takes 3 minutes and 003 takes 15, a task depending only on 002 starts at minute 3.

- 10 independent tasks: all start at once (up to the limit), bounded by the slowest
- Deep plans with uneven task sizes gain the most over lockstep batches
- Concurrency is Claude Code's subagent limit (20 by default; raise it with `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`), so very wide plans queue rather than all starting at once
