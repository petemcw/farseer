#!/bin/bash
# PreToolUse hook: block destructive git commands before Claude runs them.
#
# Exit 2 blocks the command (stderr is shown to Claude); exit 0 allows it.
# This is a guardrail against accidents, not a security boundary: a command
# wrapped in `bash -c "..."` or `eval` is not inspected.

block() {
  printf "BLOCKED: '%s' %s. The user has prevented you from doing this.\n" "$COMMAND" "$1" >&2
  exit 2
}

# True when the subcommand's arguments (space-padded) match an ERE.
has() { printf '%s' "$args" | grep -qE "$1"; }

# Fail closed. Without jq the command cannot be read, and allowing everything
# would silently turn the guardrail off.
if ! command -v jq >/dev/null 2>&1; then
  printf 'BLOCKED: git-guardrails needs jq to inspect commands, and jq is not installed.\n' >&2
  exit 2
fi

COMMAND="$(jq -r '.tool_input.command // empty')" || {
  printf 'BLOCKED: git-guardrails could not parse the hook input.\n' >&2
  exit 2
}

# Split into one simple command per line at ; & | ( ) and backticks, so
# `cd x && git push` is checked as two commands. Tabs become spaces.
# shellcheck disable=SC2020  # a deliberate one-to-one character map
segments="$(printf '%s\n' "$COMMAND" | tr ';&|()`\t' '\n\n\n\n\n\n ')"

while IFS= read -r seg; do
  # Drop leading spaces, VAR=value assignments, and sudo/command/exec.
  seg="$(printf '%s' "$seg" | sed -E \
    -e 's/^ +//' \
    -e 's/^([A-Za-z_][A-Za-z0-9_]*=[^ ]* +)*//' \
    -e 's/^(sudo|command|exec) +//' \
    -e 's/  +/ /g')"
  case "$seg" in
    git|git\ *) ;;
    *) continue ;;
  esac

  # Strip git's global options (-C dir, -c k=v, --no-pager, --git-dir=x, ...)
  # to reach the subcommand.
  rest="$(printf '%s' "${seg#git}" | sed -E \
    -e ':a' \
    -e 's/^ +(-C|-c|--git-dir|--work-tree|--namespace) +[^ ]+//' \
    -e 'ta' \
    -e 's/^ +--[a-z-]+(=[^ ]+)?( |$)/ /' \
    -e 'ta' \
    -e 's/^ +-[pP]( |$)/ /' \
    -e 'ta' \
    -e 's/^ +//')"
  sub="${rest%% *}"
  args=" ${rest#"$sub"} "

  case "$sub" in
    push)
      block "pushes to a remote"
      ;;
    reset)
      has ' --hard ' && block "discards uncommitted changes (reset --hard)"
      ;;
    clean)
      has ' (--force|-[a-zA-Z]*f[a-zA-Z]*) ' && block "deletes untracked files (clean -f)"
      ;;
    branch)
      has ' -[a-zA-Z]*D[a-zA-Z]* ' && block "force-deletes a branch (branch -D)"
      if has ' (--delete|-[a-zA-Z]*d[a-zA-Z]*) ' && has ' (--force|-[a-zA-Z]*f[a-zA-Z]*) '; then
        block "force-deletes a branch (branch --delete --force)"
      fi
      ;;
    checkout|restore)
      has ' (\.|:/|\*) ' && block "discards all working-tree changes ($sub .)"
      ;;
  esac
done <<EOF
$segments
EOF

exit 0
