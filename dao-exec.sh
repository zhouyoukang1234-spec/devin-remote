#!/bin/bash
# dao-exec — transparent remote command execution (Linux/Devin VM)
# GitHub Issues = invisible transport pipe
# Usage: dao-exec "command" → stdout = result (feels like local execution)
# Env: DAO_REPO    (default: zhouyoukang1234-spec/devin-remote)
#      DAO_TIMEOUT (default: 120s)
#      DAO_SECRET  (optional: HMAC-SHA256 key; must match agent to be accepted)
# Protocol: body = "dao1 <base64(cmd)> <hmac|->"; result comment = "dao1-result <ok> <ms>\n<base64(output)>"

REPO="${DAO_REPO:-zhouyoukang1234-spec/devin-remote}"
TIMEOUT="${DAO_TIMEOUT:-120}"
SECRET="${DAO_SECRET:-}"
LABEL="devin-cmd"

[ $# -eq 0 ] && { echo "Usage: dao-exec \"command\"" >&2; exit 1; }

# ── Build signed envelope (base64 avoids all quoting/multiline issues) ──
b64=$(printf '%s' "$*" | base64 -w0)
if [ -n "$SECRET" ]; then
  sig=$(printf '%s' "$b64" | openssl dgst -sha256 -hmac "$SECRET" -r | cut -d' ' -f1)
else
  sig="-"
fi
body="dao1 $b64 $sig"

# ── Send: create Issue = push command into pipe ──
num=$(gh issue create --repo "$REPO" --label "$LABEL" --title "cmd" --body "$body" 2>/dev/null | grep -oE '[0-9]+$')
if [ -z "$num" ]; then
  echo "dao: send failed — check: gh auth status && repo $REPO exists" >&2
  exit 1
fi

# ── Receive: poll until closed = result came back ──
deadline=$(( SECONDS + TIMEOUT ))
while [ $SECONDS -lt $deadline ]; do
  state=$(gh issue view "$num" --repo "$REPO" --json state -q .state 2>/dev/null)
  if [ "$state" = "CLOSED" ]; then
    cbody=$(gh issue view "$num" --repo "$REPO" --comments --json comments -q '.comments[-1].body' 2>/dev/null)
    marker=$(printf '%s\n' "$cbody" | head -1)
    case "$marker" in
      dao1-result*)
        status=$(printf '%s' "$marker" | awk '{print $2}')
        payload=$(printf '%s\n' "$cbody" | sed -n '2p')
        out=$(printf '%s' "$payload" | base64 -d 2>/dev/null)
        if [ "$status" = "False" ]; then
          printf '%s\n' "$out" >&2
          exit 1
        fi
        printf '%s\n' "$out"
        exit 0
        ;;
      *)
        # Fallback for legacy/markdown-fence results
        printf '%s\n' "$cbody" | sed -n '/^```$/,/^```$/ { /^```$/d; p; }'
        exit 0
        ;;
    esac
  fi
  sleep 3
done
echo "dao: timeout ${TIMEOUT}s — is agent.ps1 running on user PC?" >&2
exit 1
