#!/bin/bash
# dao-exec - run a command on the user's PC, get the output back. GitHub is just the wire.
#
# A data-only branch (default: dao-pipe) is the transport: this sender writes cmd/<id>
# (base64 of the command); the agent runs it and writes res/<id> (exit code + base64 of
# the output). Plain git push/fetch only, so on a Devin VM it works with zero config
# through the built-in git proxy - no GitHub API token.
#
#   dao-exec "hostname"      # stdout = the command's output, like a local shell
#
# Env: DAO_REPO (default zhouyoukang1234-spec/devin-remote) | DAO_PIPE (dao-pipe)
#      DAO_TIMEOUT (120s) | DAO_CACHE ($HOME/.dao-pipe) | DAO_REMOTE (git URL override)
set -u
REPO="${DAO_REPO:-zhouyoukang1234-spec/devin-remote}"
PIPE="${DAO_PIPE:-dao-pipe}"
TIMEOUT="${DAO_TIMEOUT:-120}"
REMOTE="${DAO_REMOTE:-https://github.com/$REPO.git}"   # git proxy/insteadOf rewrites this on a Devin VM
CACHE="${DAO_CACHE:-$HOME/.dao-pipe}/$(printf '%s' "$REPO" | tr '/:' '__')"
GIT="git -C $CACHE -c user.name=dao -c user.email=dao@pipe -c core.autocrlf=false"

[ $# -eq 0 ] && { echo "Usage: dao-exec \"command\"" >&2; exit 1; }

# push HEAD to the pipe branch, rebasing past concurrent pushes (files are disjoint)
push_retry() {
  local i
  for i in 1 2 3 4 5 6; do
    if $GIT push -q origin "HEAD:$PIPE" 2>/dev/null; then return 0; fi
    $GIT fetch -q origin "$PIPE" 2>/dev/null || return 1
    $GIT rebase -q "origin/$PIPE" 2>/dev/null || { $GIT rebase --abort 2>/dev/null; return 1; }
  done
  return 1
}

# local working clone of just the pipe branch (created once, reused)
if [ ! -d "$CACHE/.git" ]; then
  mkdir -p "$CACHE"; git -C "$CACHE" init -q; git -C "$CACHE" remote add origin "$REMOTE"
fi
$GIT remote set-url origin "$REMOTE"
if $GIT fetch -q origin "$PIPE" 2>/dev/null; then
  $GIT checkout -q -B "$PIPE" FETCH_HEAD
else
  # pipe branch does not exist yet -> create it as an empty orphan
  $GIT checkout -q --orphan "$PIPE" 2>/dev/null || $GIT checkout -q "$PIPE"
  $GIT rm -rqf . 2>/dev/null || true
  mkdir -p "$CACHE/cmd"; : > "$CACHE/.keep"; $GIT add .keep
  $GIT commit -q -m "dao: init pipe" 2>/dev/null || true
  push_retry || { echo "dao: cannot create pipe branch on $REPO" >&2; exit 1; }
fi

# send: cmd/<id> = base64(command)
id="$(date -u +%s%3N)-$RANDOM"
mkdir -p "$CACHE/cmd"
printf '%s' "$*" | base64 -w0 > "$CACHE/cmd/$id"
$GIT add "cmd/$id"; $GIT commit -q -m "dao: cmd $id"
push_retry || { echo "dao: send failed (git push to $REPO/$PIPE)" >&2; exit 1; }
echo "[dao] sent $id: $*" >&2

# receive: poll until res/<id> appears = output came back
deadline=$(( SECONDS + TIMEOUT ))
while [ $SECONDS -lt $deadline ]; do
  $GIT fetch -q origin "$PIPE" 2>/dev/null && $GIT reset -q --hard "origin/$PIPE" 2>/dev/null
  if [ -f "$CACHE/res/$id" ]; then
    code=$(head -1 "$CACHE/res/$id" | tr -dc '0-9')
    sed -n '2p' "$CACHE/res/$id" | base64 -d 2>/dev/null
    exit "${code:-0}"
  fi
  sleep 3
done
echo "dao: timeout ${TIMEOUT}s - is agent.ps1 running on the user PC?" >&2
exit 1
