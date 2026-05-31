#!/bin/bash
# dao-exec — transparent remote command execution (Linux/Devin VM)
# GitHub Issues = invisible transport pipe
# Usage: dao-exec "command" → stdout = result (feels like local execution)
# Env: DAO_REPO (default: zhouyoukang1234-spec/devin-remote)
#      DAO_TIMEOUT (default: 120s)

REPO="${DAO_REPO:-zhouyoukang1234-spec/devin-remote}"
TIMEOUT="${DAO_TIMEOUT:-120}"
LABEL="devin-cmd"

[ $# -eq 0 ] && { echo "Usage: dao-exec \"command\"" >&2; exit 1; }

# ── Send: create Issue = push command into pipe ──
num=$(gh issue create --repo "$REPO" --label "$LABEL" --title "cmd" --body "$*" 2>/dev/null | grep -oE '[0-9]+$')
if [ -z "$num" ]; then
  echo "dao: send failed — check: gh auth status && repo $REPO exists" >&2
  exit 1
fi

# ── Receive: poll until closed = result came back ──
deadline=$(( SECONDS + TIMEOUT ))
while [ $SECONDS -lt $deadline ]; do
  state=$(gh issue view "$num" --repo "$REPO" --json state -q .state 2>/dev/null)
  if [ "$state" = "CLOSED" ]; then
    # Extract output from code block in last comment
    gh issue view "$num" --repo "$REPO" --comments --json comments \
      -q '.comments[-1].body' 2>/dev/null \
      | sed -n '/^```$/,/^```$/ { /^```$/d; p; }'
    exit 0
  fi
  sleep 3
done
echo "dao: timeout ${TIMEOUT}s — is agent.ps1 running on user PC?" >&2
exit 1
