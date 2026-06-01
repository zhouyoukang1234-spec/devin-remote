# Offline end-to-end test harness

`e2e.sh` runs the **real** `agent.ps1` (receiver) and `dao-exec.sh` (sender) against a
local **bare git repo** that stands in for GitHub - so the whole pipe is exercised with
no real repo, token, or network. This is how it is validated in sandboxes where
`api.github.com` is unreachable.

## Requirements
- `pwsh` (PowerShell 7+) **or** Windows PowerShell 5.1 (`powershell.exe`) - auto-detected
- `git`, `openssl`, `base64` (no `python` needed)

On Git Bash for Windows it also uses `cygpath` (ships with Git for Windows) so bash-git
and PowerShell-git agree on the bare repo path.

## Run
```bash
bash test/e2e.sh
```

It inits a bare repo, seeds a pre-boot (stale) command, boots `agent.ps1`, drives
commands through `dao-exec.sh`, and prints `PASS`/`FAIL` per case. Exit code = failures.

## What it covers
- basic round-trip (signed)
- multiline / unicode / shell-metacharacter output (base64 round-trip, byte-exact)
- command failure -> non-zero exit + stderr
- HMAC: a command signed with the wrong secret is rejected
- stale-skip: a command seeded before the agent booted is never executed
