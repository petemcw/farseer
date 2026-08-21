# Farseer

An plugin for autonomous development orchestration with parallel TDD execution. This repo *is* the plugin. It contains no application code, only markdown (skills, agents, docs) and bash (hooks, tests).

This file is Farseer's own project config. It is **not** the template shipped to
users.

## Do not use Farseer to build Farseer

Do **not** invoke `/farseer:planner` or `/farseer:orchestrate` for work in this repo. Farseer cannot bootstrap itself. Farseer requires documentation which this repo deliberately does not have, and its hook agents would resolve against the very `agents/` directory being edited. Work here directly, TDD where practical.

The plugin's own workflow is for *consumer* projects.

## Commands

```bash
# Lint shell
shellcheck hooks/*.sh tests/*.sh
```

## Key Conventions

- **Shell must run on bash 3.2** (stock macOS `/bin/bash`). No `declare -A`, no `mapfile`, no `${var,,}`. Use parallel indexed arrays instead of associative ones.
- **`LC_ALL=C` on every `sort` and `awk`**, or ordering differs between a macOS `en_US.UTF-8` user and a Linux `C` one.
- **BSD tools only** — no `grep -P`, no GNU `sed -i` semantics, no awk `gensub`. The plugin ships to macOS and Linux.
- **Never `ls "$DIR"/*.md`** — plugin install paths contain spaces. Use `shopt -s nullglob` with a `for` glob loop, and quote every path expansion.
- Hook scripts self-locate via `${BASH_SOURCE[0]}`; project root comes from `${CLAUDE_PROJECT_DIR:-$PWD}`.
- **`${CLAUDE_PLUGIN_ROOT}` is only set for `hooks.json` entries**, not for a skill's Bash calls. Skills use the `Base directory for this skill` value the harness states at load.
- `HOOKS.md` is the authoritative reference for the hook system. Skills point there rather than restating the routine.
- Hook discovery is `hooks/discover-hooks.sh`. Never enumerate agent files by hand or write a glob loop to do it.

## Release Process

This repo is a Claude Code plugin published via its own marketplace manifest.

To cut a new release:

1. Bump `version` in **both** `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (must match, or `claude plugin tag` refuses).
2. Commit the version bump.
3. Run `claude plugin tag --push` — auto-generates a tag in the form `farseer--v{version}` (note the **double dash** between plugin name and `v`) and pushes it. `--dry-run` previews without creating anything.
4. Mirror to GitHub Releases: `gh release create farseer--v{version} --title "farseer--v{version}" --latest`. **Always pass `--latest`** — without it GitHub picks the "Latest" badge by creation timestamp, which is wrong given this repo's tags are already out of chronological order.
5. Users update via `/plugin marketplace update farseer`, then `/plugin install farseer@farseer`, then `/reload-plugins`. The reload step is non-obvious and required.

**Versioning:** semver, read as `BREAKING.FEATURE.FIX`. New phases / agents / skills = minor. Removing a generated file is treated as minor since existing user data isn't destroyed.
