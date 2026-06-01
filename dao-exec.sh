#!/bin/bash
# dao-exec - transparent remote command execution over a GIT branch (Linux/Devin VM)
# A data-only orphan branch (default: dao-pipe) is the transport: the sender writes
# cmd/<id>, the agent writes res/<id>. Uses ONLY git push/fetch, so on a Devin VM it
# works with zero config through the built-in git proxy -- no GitHub API token needed.
#
# Usage: dao-exec "command"       -> stdout = result (feels like local execution)
# Env:  DAO_REPO    (default: zhouyoukang1234-spec/devin-remote)
#       DAO_PIPE    (default: dao-pipe)
#       DAO_TIMEOUT (default: 120 seconds)
#       DAO_SECRET  (optional: HMAC-SHA256 key; must match the agent to be accepted)
#       DAO_CACHE   (default: $HOME/.dao-pipe ; local working clone of the pipe branch)
# Protocol: cmd/<id> = "dao1 <base64(cmd)> <hmac|->"
#           res/<id> = "dao1-result <True|False> <ms>\n<base64(output)>"
set -u
REPO="${DAO_REPO:-zhouyoukang1234-spec/devin-remote}"
PIPE="${DAO_PIPE:-dao-pipe}"
TIMEOUT="${DAO_TIMEOUT:-120}"
SECRET="${DAO_SECRET:-}"
REMOTE="${DAO_REMOTE:-https://github.com/$REPO.git}"   # git insteadOf/proxy rewrites this on a Devin VM
CACHE="${DAO_CACHE:-$HOME/.dao-pipe}/$(printf '%s' "$REPO" | tr '/:' '__')"
GIT="git -C $CACHE -c user.name=dao -c user.email=dao@pipe -c core.autocrlf=false"

[ $# -eq 0 ] && { echo "Usage: dao-exec \"command\"" >&2; exit 1; }

# -- Local working clone of just the pipe branch (created once, reused) --
ensure_clone() {
  if [ ! -d "$CACHE/.git" ]; then
    mkdir -p "$CACHE"
    git -C "$CACHE" init -q
    git -C "$CACHE" remote add origin "$REMOTE"
  fi
  if $GIT fetch -q --depth=1 origin "$PIPE" 2>/dev/null; then
    $GIT checkout -q -B "$PIPE" FETCH_HEAD
  else
    # Pipe branch does not exist yet -> create it as an empty orphan.
    $GIT checkout -q --orphan "$PIPE" 2>/dev/null || $GIT checkout -q "$PIPE"
    $GIT rm -rqf . 2>/dev/null || true
    mkdir -p "$CACHE/cmd" "$CACHE/res"
    : > "$CACHE/.keep"
    $GIT add .keep
    $GIT commit -q -m "dao: init pipe" 2>/dev/null || true
    push_retry || { echo "dao: cannot create pipe branch on $REPO (git push failed)" >&2; exit 1; }
  fi
}

# -- Push HEAD to the pipe branch, rebasing onto concurrent pushes (files are disjoint) --
push_retry() {
  local i
  for i in 1 2 3 4 5 6; do
    if $GIT push -q origin "HEAD:$PIPE" 2>/dev/null; then return 0; fi
    $GIT fetch -q origin "$PIPE" 2>/dev/null || return 1
    $GIT rebase -q "origin/$PIPE" 2>/dev/null || { $GIT rebase --abort 2>/dev/null; return 1; }
  done
  return 1
}

ensure_clone

# -- Send: write cmd/<id> = push command into the pipe --
id="$(date -u +%s%3N)-$RANDOM"
b64=$(printf '%s' "$*" | base64 -w0)
if [ -n "$SECRET" ]; then
  sig=$(printf '%s' "$b64" | openssl dgst -sha256 -hmac "$SECRET" -r | cut -d' ' -f1)
else
  sig="-"
fi
mkdir -p "$CACHE/cmd" "$CACHE/res"
printf 'dao1 %s %s\n' "$b64" "$sig" > "$CACHE/cmd/$id"
$GIT add "cmd/$id"
$GIT commit -q -m "dao: cmd $id"
push_retry || { echo "dao: send failed (git push to $REPO/$PIPE)" >&2; exit 1; }
echo "[dao] sent $id: $*" >&2

# -- Receive: poll the pipe until res/<id> appears = result came back --
deadline=$(( SECONDS + TIMEOUT ))
while [ $SECONDS -lt $deadline ]; do
  $GIT fetch -q origin "$PIPE" 2>/dev/null && $GIT reset -q --hard "origin/$PIPE" 2>/dev/null
  if [ -f "$CACHE/res/$id" ]; then
    marker=$(head -1 "$CACHE/res/$id")
    status=$(printf '%s' "$marker" | awk '{print $2}')
    out=$(sed -n '2p' "$CACHE/res/$id" | base64 -d 2>/dev/null)
    if [ "$status" = "False" ]; then printf '%s\n' "$out" >&2; exit 1; fi
    printf '%s\n' "$out"
    exit 0
  fi
  sleep 3
done
echo "dao: timeout ${TIMEOUT}s - is agent.ps1 running on the user PC?" >&2
exit 1
