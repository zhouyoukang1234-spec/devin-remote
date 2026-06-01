#!/bin/bash
# End-to-end test of the REAL agent.ps1 + dao-exec.ps1 over a local mock of the
# GitHub Issues API (test/mock_github.py). No network / no real GitHub needed.
#
# Requires: pwsh 7+ OR Windows PowerShell 5.1; python3 OR python; openssl, base64.
# Run:  bash test/e2e.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PORT="${DAO_TEST_PORT:-8765}"
API="http://127.0.0.1:$PORT"
SECRET="s3cr3t"
export DAO_TOKEN="tok-test"
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy 2>/dev/null

# Portable runtimes: prefer pwsh 7+/python3, fall back to Windows PowerShell 5.1/python.
PSH="$(command -v pwsh || command -v powershell)"; [ -z "$PSH" ] && { echo "need pwsh or powershell"; exit 2; }
PY="$(command -v python3 || command -v python)";   [ -z "$PY"  ] && { echo "need python3 or python";  exit 2; }
# Under Git Bash, $ROOT is an MSYS path (/c/...). MSYS only auto-converts standalone
# path args, not paths embedded in a -Command string, so hand PowerShell a native path.
winpath(){ command -v cygpath >/dev/null 2>&1 && cygpath -w "$1" || echo "$1"; }
ROOTW="$(winpath "$ROOT")"
echo "# using shell=$PSH python=$PY root=$ROOTW"
pass=0; fail=0
ok(){ echo "PASS: $1"; pass=$((pass+1)); }
no(){ echo "FAIL: $1 -- $2"; fail=$((fail+1)); }

cleanup(){ [ -n "${AGENT_PID:-}" ] && kill "$AGENT_PID" 2>/dev/null
           [ -n "${MOCK_PID:-}" ]  && kill "$MOCK_PID"  2>/dev/null; }
trap cleanup EXIT

start_agent(){ # $1 = secret ("" for unsigned); writes /tmp/dao_agent.log
  [ -n "${AGENT_PID:-}" ] && kill "$AGENT_PID" 2>/dev/null; sleep 1
  SARG=""; [ -n "$1" ] && SARG="-Secret '$1'"
  # -Command + *>&1 so Write-Host (PS 5.1 routes it to the information stream,
  # which a plain '>' does NOT capture) lands in the log on every PS edition.
  "$PSH" -NoProfile -ExecutionPolicy Bypass -Command \
     "& '$ROOTW\\agent.ps1' -Repo 'test/repo' -Token 'tok-test' -ApiBase '$API' $SARG *>&1" \
     > /tmp/dao_agent.log 2>&1 &
  AGENT_PID=$!; sleep 6
}
dex(){ # $1 secret("-" none) $2 cmd ; sets OUT/RC, stderr->/tmp/dex.err
  if [ "$1" = "-" ]; then
    OUT=$("$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOTW\\dao-exec.ps1" -Repo "test/repo" -ApiBase "$API" -Command "$2" 2>/tmp/dex.err); RC=$?
  else
    OUT=$("$PSH" -NoProfile -ExecutionPolicy Bypass -File "$ROOTW\\dao-exec.ps1" -Repo "test/repo" -ApiBase "$API" -Secret "$1" -Command "$2" 2>/tmp/dex.err); RC=$?
  fi
}

"$PY" "$HERE/mock_github.py" "$PORT" > /tmp/dao_mock.log 2>&1 & MOCK_PID=$!
sleep 1
curl -s "$API/user" | grep -q '"login"' || { echo "mock not up"; exit 2; }

echo "########## SIGNED AGENT ##########"
start_agent "$SECRET"
# A long-running agent buffers stdout, so the banner never reaches the log file;
# readiness = the process is still alive after boot (a parse error would exit it).
kill -0 "$AGENT_PID" 2>/dev/null && ok "agent up (signed)" || no "agent up" "agent died: $(tail -3 /tmp/dao_agent.log)"

dex "$SECRET" "Write-Output 'simple-ok'";                 { [ "$OUT" = "simple-ok" ] && [ $RC -eq 0 ]; } && ok "simple output" || no "simple" "OUT=[$OUT] RC=$RC"
dex "$SECRET" "Write-Output 'l1'; Write-Output 'l2'";      [ "$(printf '%s' "$OUT" | tr -d '\r' | tr '\n' '|')" = "l1|l2" ] && ok "multiline" || no "multiline" "[$OUT]"
dex "$SECRET" "Write-Output '\`\`\`x\`\`\`'; Write-Output 'q\"q'"; { echo "$OUT" | grep -q '```x```' && echo "$OUT" | grep -q 'q"q'; } && ok "backticks+quote round-trip" || no "tricky" "[$OUT]"
# Generate the unicode agent-side (codepoints) so it never traverses the powershell.exe
# argv boundary (which would mojibake it) -- this isolates the base64 result channel.
dex "$SECRET" "Write-Output ([char]0x9053+[char]0x6CD5+[char]0x81EA+[char]0x7136)"; [ "$(printf '%s' "$OUT" | tr -d '\r')" = "道法自然" ] && ok "unicode (UTF-8) round-trip" || no "unicode" "[$OUT]"
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
DEC=$(curl -s "$API/repos/test/repo/issues/$INJN/comments" | "$PY" -c "import sys,json,base64;a=json.load(sys.stdin);b=a[-1]['body'].split('\n');print(base64.b64decode(b[1]).decode() if len(b)>1 else '')" 2>/dev/null)
echo "$DEC" | grep -q 'skipped: stale' && ok "backlog skipped (not executed)" || no "backlog" "[$DEC]"

echo "########## CONCURRENCY / DEDUP ##########"
dex "$SECRET" "Write-Output 'c1'" & p1=$!
dex "$SECRET" "Write-Output 'c2'" & p2=$!
dex "$SECRET" "Write-Output 'c3'" & p3=$!
wait "$p1" "$p2" "$p3"
DUP=$(curl -s "$API/_control/dump" | "$PY" -c "import sys,json;d=json.load(sys.stdin);print(sum(1 for i in d if i['state']=='closed' and sum(1 for c in i['comments'] if c['body'].startswith('dao1-result'))!=1))")
[ "$DUP" = "0" ] && ok "no duplicate results" || no "dedup" "bad=$DUP"

echo "########## UNSIGNED AGENT (zero-config default) ##########"
curl -s -X POST "$API/_control/reset" >/dev/null
start_agent ""
kill -0 "$AGENT_PID" 2>/dev/null && ok "agent up (unsigned)" || no "agent up unsigned" "agent died: $(tail -3 /tmp/dao_agent.log)"
dex - "Write-Output 'unsigned-ok'";       { [ "$OUT" = "unsigned-ok" ] && [ $RC -eq 0 ]; } && ok "unsigned sender accepted" || no "u1" "OUT=[$OUT] RC=$RC"
dex anything "Write-Output 'signed-ok'";  { [ "$OUT" = "signed-ok" ] && [ $RC -eq 0 ]; } && ok "signed sender accepted by unsigned agent" || no "u2" "OUT=[$OUT] RC=$RC"

echo
echo "================ RESULT: $pass passed, $fail failed ================"
exit $fail
