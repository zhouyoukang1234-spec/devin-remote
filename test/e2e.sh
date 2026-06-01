#!/bin/bash
# Offline end-to-end test for the git pipe (dao-exec.sh sender + agent.ps1 receiver).
# A local bare repo stands in for GitHub, so it never touches the network. It proves the
# cmd/<id> + res/<id> branch protocol, clock-free baseline skip, unicode, metacharacters
# and failure-code propagation.
#
# Portable: prefers pwsh 7+, falls back to Windows PowerShell 5.1. On Git Bash it uses
# cygpath so bash-git and PowerShell-git agree on the bare repo path.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PSH="$(command -v pwsh || command -v powershell)"; [ -z "$PSH" ] && { echo "need pwsh or powershell"; exit 2; }
winpath(){ command -v cygpath >/dev/null 2>&1 && cygpath -m "$1" || echo "$1"; }
AGENTW="$(winpath "$ROOT/agent.ps1")"

PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1 ${2:+-- $2}"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
HUB="$WORK/hub.git"; REMOTE="$(winpath "$HUB")"
PIPE="dao-pipe"
export DAO_REMOTE="$REMOTE" DAO_PIPE="$PIPE" DAO_REPO="test/repo" DAO_TIMEOUT="40"

cleanup(){ [ -n "${AGENT_PID:-}" ] && kill "$AGENT_PID" 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

git init -q --bare "$HUB"

# Seed a command on the pipe BEFORE the agent boots, to prove the agent never executes
# backlog on (re)connect (clock-free baseline = ignore whatever already exists at startup).
SEED="$WORK/seed"
git clone -q "$HUB" "$SEED"
git -C "$SEED" checkout -q --orphan "$PIPE"
mkdir -p "$SEED/cmd"
STALE_ID="1000000000000-stale"
printf '%s' "$(printf '%s' "Write-Output STALE" | base64 -w0)" > "$SEED/cmd/$STALE_ID"
git -C "$SEED" -c user.name=t -c user.email=t@t add . >/dev/null
git -C "$SEED" -c user.name=t -c user.email=t@t commit -qm seed
git -C "$SEED" push -q origin "$PIPE"

# Start the agent (receiver). Its cache is separate from the sender's = two machines.
export DAO_CACHE="$WORK/agent-cache"
"$PSH" -NoProfile -ExecutionPolicy Bypass -Command "& '$AGENTW' -Repo 'test/repo'" > "$WORK/agent.log" 2>&1 &
AGENT_PID=$!
sleep 6
kill -0 "$AGENT_PID" 2>/dev/null && ok "agent up" || no "agent up" "died: $(tail -5 "$WORK/agent.log")"

# Sender helper with its own cache. Usage: dex "<cmd>"
dex(){ DAO_CACHE="$WORK/send-cache" bash "$ROOT/dao-exec.sh" "$1" 2>"$WORK/dex.err"; }

# 1) basic round-trip
OUT=$(dex "Write-Output hi"); RC=$?
[ "$RC" = 0 ] && [ "$(printf '%s' "$OUT" | tr -d '\r')" = "hi" ] && ok "basic round-trip" || no "basic round-trip" "rc=$RC out=[$OUT]"

# 2) multiline (PS joins with CRLF; strip CR before comparing)
OUT=$(dex "Write-Output 'l1'; Write-Output 'l2'")
[ "$(printf '%s' "$OUT" | tr -d '\r' | tr '\n' '|')" = "l1|l2" ] && ok "multiline" || no "multiline" "[$OUT]"

# 3) unicode generated agent-side via code points (never crosses argv)
OUT=$(dex "Write-Output ([char]0x9053+[char]0x6CD5+[char]0x81EA+[char]0x7136)")
EXP=$(printf '\xe9\x81\x93\xe6\xb3\x95\xe8\x87\xaa\xe7\x84\xb6')
[ "$(printf '%s' "$OUT" | tr -d '\r')" = "$EXP" ] && ok "unicode (UTF-8) round-trip" || no "unicode" "[$OUT]"

# 4) failure path: throw -> exit code propagates (sender exits non-zero), output returned
OUT=$(dex "throw 'boom'"); RC=$?
[ "$RC" != 0 ] && printf '%s' "$OUT" | grep -q boom && ok "failure code propagates" || no "failure code" "rc=$RC out=[$OUT]"

# 5) shell metacharacters survive base64 round-trip
OUT=$(dex "Write-Output 'a\`\"b|c&d;e'")
[ "$(printf '%s' "$OUT" | tr -d '\r')" = 'a`"b|c&d;e' ] && ok "metacharacters byte-exact" || no "metacharacters" "[$OUT]"

# 6) the pre-boot (baseline) command must NOT have been executed
if git -C "$WORK/agent-cache/test_repo" cat-file -e "origin/$PIPE:res/$STALE_ID" 2>/dev/null; then
  no "baseline skip" "res for pre-boot id exists"
else
  ok "baseline skip (no res for pre-boot cmd)"
fi

echo "------"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = 0 ] || exit 1
