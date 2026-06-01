#!/bin/bash
# Offline end-to-end test for the GIT transport (dao-git.sh sender + agent-git.ps1 receiver).
# A local bare repo stands in for GitHub, so this never touches the network: it proves the
# cmd/<id> + res/<id> branch protocol, HMAC signing, stale-skip, unicode and failure paths.
#
# Portable: prefers pwsh 7+/python3, falls back to Windows PowerShell 5.1. On Git Bash it
# uses cygpath so both bash-git and PowerShell-git agree on the bare repo path.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PSH="$(command -v pwsh || command -v powershell)"; [ -z "$PSH" ] && { echo "need pwsh or powershell"; exit 2; }
winpath(){ command -v cygpath >/dev/null 2>&1 && cygpath -m "$1" || echo "$1"; }
AGENTW="$(winpath "$ROOT/agent-git.ps1")"

PASS=0; FAIL=0
ok(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL: $1 ${2:+-- $2}"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
HUB="$WORK/hub.git"; REMOTE="$(winpath "$HUB")"
SECRET="s3cr3t"; PIPE="dao-pipe"
export DAO_REMOTE="$REMOTE" DAO_PIPE="$PIPE" DAO_REPO="test/repo" DAO_SECRET="$SECRET" DAO_TIMEOUT="40"

cleanup(){ [ -n "${AGENT_PID:-}" ] && kill "$AGENT_PID" 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

git init -q --bare "$HUB"

# Seed the pipe branch with a STALE command (id timestamp far in the past) BEFORE the agent
# boots, to prove the agent never executes backlog on (re)connect.
SEED="$WORK/seed"
git clone -q "$HUB" "$SEED"
git -C "$SEED" checkout -q --orphan "$PIPE"
mkdir -p "$SEED/cmd" "$SEED/res"
STALE_ID="1000000000000-stale"
b64=$(printf '%s' "Write-Output STALE" | base64 -w0)
sig=$(printf '%s' "$b64" | openssl dgst -sha256 -hmac "$SECRET" -r | cut -d' ' -f1)
printf 'dao1 %s %s\n' "$b64" "$sig" > "$SEED/cmd/$STALE_ID"
git -C "$SEED" -c user.name=t -c user.email=t@t add . >/dev/null
git -C "$SEED" -c user.name=t -c user.email=t@t commit -qm seed
git -C "$SEED" push -q origin "$PIPE"

# Start the agent (git receiver). Its cache is separate from the sender's = two machines.
export DAO_CACHE="$WORK/agent-cache"
"$PSH" -NoProfile -ExecutionPolicy Bypass -Command \
  "& '$AGENTW' -Repo 'test/repo' -Secret '$SECRET'" > "$WORK/agent.log" 2>&1 &
AGENT_PID=$!
sleep 6
kill -0 "$AGENT_PID" 2>/dev/null && ok "agent up (signed)" || no "agent up" "died: $(tail -5 "$WORK/agent.log")"

# Sender helper: dao-git.sh with its OWN cache. Usage: dex <secret> "<cmd>"
dex(){ DAO_SECRET="$1" DAO_CACHE="$WORK/send-cache-$1" bash "$ROOT/dao-git.sh" "$2" 2>"$WORK/dex.err"; }

# 1) basic round-trip
OUT=$(dex "$SECRET" "Write-Output hi"); RC=$?
[ "$RC" = 0 ] && [ "$(printf '%s' "$OUT" | tr -d '\r')" = "hi" ] && ok "basic round-trip" || no "basic round-trip" "rc=$RC out=[$OUT]"

# 2) multiline (strip CR before comparing; PS joins with CRLF)
OUT=$(dex "$SECRET" "Write-Output 'l1'; Write-Output 'l2'")
[ "$(printf '%s' "$OUT" | tr -d '\r' | tr '\n' '|')" = "l1|l2" ] && ok "multiline" || no "multiline" "[$OUT]"

# 3) unicode generated agent-side via code points (never crosses argv)
OUT=$(dex "$SECRET" "Write-Output ([char]0x9053+[char]0x6CD5+[char]0x81EA+[char]0x7136)")
EXP=$(printf '\xe9\x81\x93\xe6\xb3\x95\xe8\x87\xaa\xe7\x84\xb6')
[ "$(printf '%s' "$OUT" | tr -d '\r')" = "$EXP" ] && ok "unicode (UTF-8) round-trip" || no "unicode" "[$OUT]"

# 4) failure path: throw -> status False -> sender exits 1, error on stderr
OUT=$(dex "$SECRET" "throw 'boom'"); RC=$?
[ "$RC" = 1 ] && grep -q boom "$WORK/dex.err" && ok "failure path (exit 1 + stderr)" || no "failure path" "rc=$RC err=[$(cat "$WORK/dex.err")]"

# 5) wrong signature is rejected (agent requires $SECRET; send with a different key)
OUT=$(dex "wrongkey" "Write-Output nope"); RC=$?
[ "$RC" = 1 ] && grep -qi signature "$WORK/dex.err" && ok "wrong signature rejected" || no "wrong signature rejected" "rc=$RC err=[$(cat "$WORK/dex.err")]"

# 6) shell metacharacters survive base64 round-trip
OUT=$(dex "$SECRET" "Write-Output 'a\`\"b|c&d;e'")
[ "$(printf '%s' "$OUT" | tr -d '\r')" = 'a`"b|c&d;e' ] && ok "metacharacters byte-exact" || no "metacharacters" "[$OUT]"

# 7) stale command seeded before boot must NOT have been executed
if git -C "$WORK/agent-cache/test_repo" cat-file -e "origin/$PIPE:res/$STALE_ID" 2>/dev/null; then
  no "stale command skipped" "res for stale id exists"
else
  ok "stale command skipped (no res for pre-boot cmd)"
fi

echo "------"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = 0 ] || exit 1
