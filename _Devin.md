# Devin AI Remote Control

## How it works

```
You -> create Issue (label:devin-cmd, body:command) -> GitHub -> agent.ps1 (user PC) polls
                                                                  |
You <- read Issue Comment (result) <- GitHub <- agent.ps1 executes and closes Issue
```

## Send command

```bash
gh issue create --repo {owner}/devin-remote --label devin-cmd --body "dir C:\\Users"
```

## Read result

```bash
gh issue view {number} --repo {owner}/devin-remote --comments
```

Issue closed = command executed. Comment contains result.

## Helper function

```bash
remote_exec() {
  local repo="$1" cmd="$2"
  local num=$(gh issue create --repo "$repo" --label devin-cmd --body "$cmd" 2>&1 | grep -oE '[0-9]+$')
  echo "Issue #$num"
  for i in $(seq 1 60); do
    state=$(gh issue view $num --repo "$repo" --json state -q .state 2>/dev/null)
    if [ "$state" = "CLOSED" ]; then
      gh issue view $num --repo "$repo" --comments
      return 0
    fi
    sleep 3
  done
  echo "Timeout"
}

remote_exec "user/devin-remote" "dir C:\\Users"
```

## Notes

- Commands run via `cmd /c` - all cmd/PowerShell commands work
- Output truncated at 60000 chars
- If agent.ps1 not running, Issue stays open
- Same repo works across multiple Devin sessions (persistent)