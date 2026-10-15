#!/usr/bin/env bash
# Tests for the hook scripts and the git-guardrails script.
# Plain bash 3.2, no framework. Every scratch project path contains a space.
#
#   bash tests/hooks.sh

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$ROOT/hooks"
GUARD="$ROOT/skills/git-guardrails/scripts/block-dangerous-commands.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/farseer-tests.XXXXXX")" || exit 1
trap 'rm -rf "$TMP"' EXIT
TMP="$(cd "$TMP" && pwd)"  # drop the // a trailing slash in $TMPDIR leaves

PASS=0
FAIL=0

# check <description> <expected> <actual>
check() {
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
  fi
}

# contains <haystack> <needle>: prints yes or no
contains() {
  case "$1" in
    *"$2"*) echo yes ;;
    *) echo no ;;
  esac
}

# run <command...>: sets OUT, ERR and RC
run() {
  OUT="$("$@" 2>"$TMP/stderr")"
  RC=$?
  ERR="$(cat "$TMP/stderr")"
}

# new_project <name>: prints the path of a fresh project with a .farseer/ dir
new_project() {
  local p="$TMP/proj $1"
  mkdir -p "$p/.farseer"
  printf '%s' "$p"
}

# agent <project> <name> [frontmatter line...]: writes a local agent file
agent() {
  local p="$1" n="$2" line
  shift 2
  mkdir -p "$p/.claude/agents"
  {
    echo '---'
    echo "name: $n"
    for line in "$@"; do echo "$line"; done
    echo '---'
    echo 'Body.'
  } > "$p/.claude/agents/$n.md"
}

discover() { env CLAUDE_PROJECT_DIR="$P" "$HOOKS/discover-hooks.sh" "$@"; }

# --- discover-hooks.sh ------------------------------------------------------

P="$(new_project discover)"
agent "$P" padded 'phase: pre-batch' 'order: 007'
agent "$P" octal 'phase: pre-batch' 'order: 08'

run discover --json
check "json: exit 0" 0 "$RC"
check "json: zero-padded order is printed as a plain number" yes "$(contains "$OUT" '"name":"padded","order":7,')"
check "json: 08 is read as decimal, not octal" yes "$(contains "$OUT" '"name":"octal","order":8,')"
check "json: no leading-zero numbers" no "$(contains "$OUT" '":0')"

run discover --hook=pre-batch
check "hook filter: lists the enrolled agent" yes "$(contains "$OUT" 'name=padded')"

# A hook with nothing enrolled must print zero bytes. Pick one the --json view
# shows as empty, so the test survives changes to the plugin's own agents.
empty_hook=""
for h in pre-plan pre-implementation post-batch pre-commit post-commit; do
  if [ "$(contains "$(discover --json)" "\"$h\":[]")" = yes ]; then
    empty_hook="$h"
    break
  fi
done
if [ -n "$empty_hook" ]; then
  run discover --hook="$empty_hook"
  check "empty hook ($empty_hook): exit 0" 0 "$RC"
  check "empty hook ($empty_hook): prints nothing" "" "$OUT"
fi

run discover --fingerprint
FP="$OUT"
check "fingerprint: format" yes "$(printf '%s' "$FP" | grep -qE '^discover-hooks-fingerprint-v1 [0-9a-f]{64}$' && echo yes || echo no)"

run discover --hook=pre-batch --expect="$FP"
check "expect: unchanged enrollment exits 0" 0 "$RC"

run discover --hook=pre-batch --expect="not-a-fingerprint"
check "expect: malformed value exits 2" 2 "$RC"

agent "$P" newcomer 'phase: post-batch'
run discover --hook=pre-batch --expect="$FP"
check "expect: changed enrollment exits 4" 4 "$RC"

agent "$P" broken 'phase: post-lunch'
run discover --hook=pre-batch
check "invalid phase exits 3" 3 "$RC"
check "invalid phase names the file" yes "$(contains "$ERR" "broken.md")"

# --- local overrides --------------------------------------------------------

# Overrides are tested against whichever plugin agent is enrolled first, so the
# tests survive changes to the plugin's own agents.
P="$(new_project overrides)"
run discover
PLUGIN_ROW="$(printf '%s\n' "$OUT" | grep -m1 'origin=plugin')"
PLUGIN_NAME="$(printf '%s' "$PLUGIN_ROW" | sed 's/.*name=//; s/ .*//')"
PLUGIN_HOOK="$(printf '%s\n' "$OUT" | awk -v n="$PLUGIN_NAME" '/^# hook: /{h=$3} index($0, "name=" n " "){print h; exit}')"
check "origin: plugin agents are labeled plugin" yes "$(contains "$PLUGIN_ROW" 'origin=plugin')"
run discover --fingerprint
FP="$OUT"

agent "$P" own-gate 'phase: pre-commit'
run discover --hook=pre-commit
check "origin: a local-only agent is labeled local" yes "$(contains "$OUT" 'origin=local')"
run discover --json --hook=pre-commit
check "origin: json carries the origin" yes "$(contains "$OUT" '"name":"own-gate","order":100,"mode":"single","origin":"local"')"
rm "$P/.claude/agents/own-gate.md"

agent "$P" "$PLUGIN_NAME"
run discover --hook="$PLUGIN_HOOK"
check "no phase: a same-named local file does not shadow the plugin agent" yes "$(contains "$OUT" 'origin=plugin')"
run discover --fingerprint
check "no phase: a same-named local file is not drift" "$FP" "$OUT"

agent "$P" "$PLUGIN_NAME" "phase: $PLUGIN_HOOK" 'order: 5'
run discover --hook="$PLUGIN_HOOK"
check "override: the local file wins" yes "$(contains "$OUT" "order=5     name=$PLUGIN_NAME")"
check "override: the winner is labeled local" yes "$(contains "$OUT" 'origin=local')"
check "override: one entry per name" 1 "$(printf '%s\n' "$OUT" | grep -c "name=$PLUGIN_NAME ")"

agent "$P" "$PLUGIN_NAME" 'phase: none'
run discover --hook="$PLUGIN_HOOK"
check "phase none: exit 0" 0 "$RC"
check "phase none: the plugin agent is no longer enrolled" no "$(contains "$OUT" "name=$PLUGIN_NAME ")"
run discover
check "phase none: the debugging view lists it as disabled" yes "$(printf '%s\n' "$OUT" | sed -n '/^# disabled/,$p' | grep -q "name=$PLUGIN_NAME " && echo yes || echo no)"
run discover --fingerprint
check "phase none: disabling an agent is drift" yes "$([ "$OUT" != "$FP" ] && echo yes || echo no)"

agent "$P" no-such-agent 'phase: none'
run discover --hook="$PLUGIN_HOOK"
check "phase none: an unknown name still exits 0" 0 "$RC"
check "phase none: an unknown name warns" yes "$(contains "$ERR" "no-such-agent")"

# --- resolve-plans-dir.sh ---------------------------------------------------

plans() { env CLAUDE_PROJECT_DIR="$P" "$HOOKS/resolve-plans-dir.sh"; }

P="$(new_project plans)"
run plans
check "plans dir: default" "$P/.farseer/plans" "$OUT"

printf '{ "plansDir": "docs/plans" }\n' > "$P/.farseer/config.json"
run plans
check "plans dir: override" "$P/docs/plans" "$OUT"

printf '{\n  "plansDir": "first",\n  "plansDir": "second"\n}\n' > "$P/.farseer/config.json"
run plans
check "plans dir: duplicate keys take the first" "$P/first" "$OUT"

printf '{ "plansDir": 5 }\n' > "$P/.farseer/config.json"
run plans
check "plans dir: non-string value exits 1" 1 "$RC"
check "plans dir: non-string value is named in the error" yes "$(contains "$ERR" "non-string")"

printf '{ "plansDir": "/etc/plans" }\n' > "$P/.farseer/config.json"
run plans
check "plans dir: absolute value exits 1" 1 "$RC"

printf '{ "plansDir": "../outside" }\n' > "$P/.farseer/config.json"
run plans
check "plans dir: '..' segment exits 1" 1 "$RC"

# --- resolve-project-dir.sh -------------------------------------------------

P="$(new_project root)"
mkdir -p "$P/a/b"

run env CLAUDE_PROJECT_DIR="$P" "$HOOKS/resolve-project-dir.sh"
check "project dir: absolute CLAUDE_PROJECT_DIR passes through" "$P" "$OUT"

OUT="$(cd "$TMP" && CLAUDE_PROJECT_DIR="proj root" "$HOOKS/resolve-project-dir.sh")"
check "project dir: relative CLAUDE_PROJECT_DIR becomes absolute" "$P" "$OUT"

run env CLAUDE_PROJECT_DIR="$TMP/missing dir" "$HOOKS/resolve-project-dir.sh"
check "project dir: nonexistent CLAUDE_PROJECT_DIR exits 1" 1 "$RC"

OUT="$(unset CLAUDE_PROJECT_DIR; cd "$P/a/b" && "$HOOKS/resolve-project-dir.sh")"
check "project dir: walks up to the .farseer/ ancestor" "$(cd "$P" && pwd -P)" "$OUT"

# --- git-guardrails ---------------------------------------------------------

if command -v jq >/dev/null 2>&1; then
  # guard <command>: prints block or allow
  guard() {
    jq -n --arg c "$1" '{tool_input: {command: $c}}' | "$GUARD" 2>/dev/null
    if [ $? -eq 2 ]; then echo block; else echo allow; fi
  }

  for c in 'git push' 'git  push --force' 'git -C sub push' 'git --no-pager push' \
           'cd x && git push' 'FOO=1 git push' 'git reset -q --hard' 'git clean -xfd' \
           'git clean --force' 'git branch -D x' 'git branch --delete --force x' \
           'git branch -d -f x' 'git checkout -- .' 'git restore .'; do
    check "guardrails blocks: $c" block "$(guard "$c")"
  done

  for c in 'git status' 'git checkout ./file.txt' 'git checkout -b feature/x' \
           'echo "git push"' 'git commit -m "docs about git push"' \
           'git branch -d merged' 'git clean -n' 'git reset --soft HEAD~1'; do
    check "guardrails allows: $c" allow "$(guard "$c")"
  done
else
  echo "skip: git-guardrails tests need jq"
fi

# --- summary ----------------------------------------------------------------

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
