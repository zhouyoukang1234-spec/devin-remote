#!/bin/bash
# End-to-end test of the REAL agent.ps1 + dao-exec.ps1 over a local mock of the
# GitHub Issues API (test/mock_github.py). No network / no real GitHub needed.
#
# Requires: pwsh (PowerShell 7+), python3, openssl, base64.
# Run:  bash test/e2e.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PORT="${DAO_TEST_PORT:-8765}"
API="http://127.0.0.1:$PORT"
SECRET="s3cr3t"
export DAO_TOKEN="tok-test"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy 2>/dev/null
pass=0; fail=0
ok(){ echo "PASS: $1"; pass=$((pass+1)); }
no(){ echo "FAIL: $1 -- $2"; fail=$((fail+1)); }

cleanup(){ [ -n "${AGENT_PID:-}" ] && kill "$AGENT_PID" 2>/dev/null
           [ -n "${MOCK_PID:-}" ]  && kill "$MOCK_PID"  2>/dev/null; }
trap cleanup EXIT

start_agent(){ # $1 = secret ("" for unsigned); writes /tmp/dao_agent.log
  [ -n "${AGENT_PID:-}" ] && kill "$AGENT_PID" 2>/dev/null; sleep 1
  if [ -n "$1" ]; then SARG=(-Secret "$1"); else SARG=(); fi
  pwsh -NoProfile -File "$ROOT/agent.ps1" -Repo "test/repo" -Token "tok-test" \
       -ApiBase "$API" "${SARG[@]}" > /tmp/dao_agent.log 2>&1 &
  AGENT_PID=$!; sleep 6
}
dex(){ # $1 secret("-" none) $2 cmd ; sets OUT/RC, stderr->/tmp/dex.err
  if [ "$1" = "-" ]; then
    OUT=$(pwsh -NoProfile -File "$ROOT/dao-exec.ps1" -Repo "test/repo" -ApiBase "$API" -Command "$2" 2>/tmp/dex.err); RC=$?
  else
    OUT=$(pwsh -NoProfile -File "$ROOT/dao-exec.ps1" -Repo "test/repo" -ApiBase "$API" -Secret "$1" -Command "$2" 2>/tmp/dex.err); RC=$?
  fi
}

python3 "$HERE/mock_github.py" "$PORT" > /tmp/dao_mock.log 2>&1 & MOCK_PID=$!
sleep 1
curl -s "$API/user" | grep -q '"login"' || { echo "mock not up"; exit 2; }

echo "########## SIGNED AGENT ##########"
start_agent "$SECRET"
grep -q 'signed=True' /tmp/dao_agent.log && ok "agent up (signed)" || no "agent up" "$(tail -2 /tmp/dao_agent.log)"

dex "$SECRET" "Write-Output 'simple-ok'";                 { [ "$OUT" = "simple-ok" ] && [ $RC -eq 0 ]; } && ok "simple output" || no "simple" "OUT=[$OUT] RC=$RC"
dex "$SECRET" "Write-Output 'l1'; Write-Output 'l2'";      [ "$(printf '%s' "$OUT" | tr '\n' '|')" = "l1|l2" ] && ok "multiline" || no "multiline" "[$OUT]"
dex "$SECRET" "Write-Output '\`\`\`x\`\`\`'; Write-Output '道 q\"q'"; { echo "$OUT" | grep -q '```x```' && echo "$OUT" | grep -q '道 q"q'; } && ok "backticks+unicode+quote" || no "tricky" "[$OUT]"
dex "$SECRET" "throw 'boom'";                              { [ $RC -eq 1 ] && grep -q boom /tmp/dex.err; } && ok "error->exit1+stderr" || no "error" "RC=$RC err=[$(cat /tmp/dex.err)]"
dex "$SECRET" "\$null = 1";                                { [ -z "$OUT" ] && [ $RC -eq 0 ]; } && ok "empty output" || no "empty" "OUT=[$OUT] RC=$RC"
dex "$SECRET" "Write-Output ('A'*70000)";                  { echo "$OUT" | grep -q '\[truncated\]' && [ ${#OUT} -gt 59000 ] && [ ${#OUT} -lt 62000 ]; } && ok "truncation@60k" || no "trunc" "len=${#OUT}"
dex "$SECRET" "Write-Output 'a|b;c && d'";                 [ "$OUT" = "a|b;c && d" ] && ok "shell metachars literal" || no "meta" "[$OUT]"

echo "########## SECURITY ##########"
dex wrongsecret "Write-Output 'NOPE'";                     { [ $RC -eq 1 ] && grep -qi signature /tmp/dex.err; } && ok "wrong secret rejected" || no "wrongsec" "RC=$RC [$(cat /tmp/dex.err)]"
dex - "Write-Output 'NOPE'";                               { [ $RC -eq 1 ] && grep -qi signature /tmp/dex.err; } && ok "unsigned sender rejected" || no "unsigned-rej" "RC=$RC [$(cat /tmp/dex.err)]"

echo "########## BACKLOG (stale skip) ##########"
B64=$(printf '%s' 'Write-Output BACKLOG-RAN' | base64 -w0)
SIG=$(printf '%s' "$B64" | openssl dgst -sha256 -hmac "$SECRET" -r | cut -d' ' -f1)
INJ=$(curl -s -X POST "$API/_control/inject" -d "{\"body\":\"dao1 $B64 $SIG\",\"labels\":[\"devin-cmd\"],\"created_at\":\"2020-01-01T00:00:00Z\"}")
INJN=$(printf '%s' "$INJ" | grep -oE '"number":[0-9]+' | grep -oE '[0-9]+'); sleep 8
DEC=$(curl -s "$API/repos/test/repo/issues/$INJN/comments" | python3 -c "import sys,json,base64;a=json.load(sys.stdin);b=a[-1]['body'].split('\n');print(base64.b64decode(b[1]).decode() if len(b)>1 else '')" 2>/dev/null)
{ echo "$DEC" | grep -q 'skipped: stale' && ! grep -q 'BACKLOG-RAN' /tmp/dao_agent.log; } && ok "backlog skipped (not executed)" || no "backlog" "[$DEC]"

echo "########## CONCURRENCY / DEDUP ##########"
dex "$SECRET" "Write-Output 'c1'" & p1=$!
dex "$SECRET" "Write-Output 'c2'" & p2=$!
dex "$SECRET" "Write-Output 'c3'" & p3=$!
wait "$p1" "$p2" "$p3"
DUP=$(curl -s "$API/_control/dump" | python3 -c "import sys,json;d=json.load(sys.stdin);print(sum(1 for i in d if i['state']=='closed' and sum(1 for c in i['comments'] if c['body'].startswith('dao1-result'))!=1))")
[ "$DUP" = "0" ] && ok "no duplicate results" || no "dedup" "bad=$DUP"

echo "########## UNSIGNED AGENT (zero-config default) ##########"
curl -s -X POST "$API/_control/reset" >/dev/null
start_agent ""
grep -q 'signed=False' /tmp/dao_agent.log && ok "agent up (unsigned)" || no "agent up unsigned" "$(tail -2 /tmp/dao_agent.log)"
dex - "Write-Output 'unsigned-ok'";       { [ "$OUT" = "unsigned-ok" ] && [ $RC -eq 0 ]; } && ok "unsigned sender accepted" || no "u1" "OUT=[$OUT] RC=$RC"
dex anything "Write-Output 'signed-ok'";  { [ "$OUT" = "signed-ok" ] && [ $RC -eq 0 ]; } && ok "signed sender accepted by unsigned agent" || no "u2" "OUT=[$OUT] RC=$RC"

echo
echo "================ RESULT: $pass passed, $fail failed ================"
exit $fail
