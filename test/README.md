# Local end-to-end test harness

Two offline harnesses, one per transport. Neither touches the network — the full
pipe is exercised with no real GitHub repo, token, or connectivity, which is how
it is validated in sandboxes where `api.github.com` is unreachable.

- `e2e.sh` — **Issues transport.** Runs the real `agent.ps1` (receiver) and
  `dao-exec.ps1` (sender) against a local in-memory mock of the GitHub Issues API
  (`mock_github.py`).
- `e2e-git.sh` — **git transport.** Runs the real `agent-git.ps1` (receiver) and
  `dao-git.sh` (sender) against a local **bare git repo** standing in for GitHub,
  proving the `dao-pipe` branch protocol (`cmd/<id>` + `res/<id>`).

## Requirements
- `pwsh` (PowerShell 7+) **or** Windows PowerShell 5.1 (`powershell.exe`) — the
  harness auto-detects whichever is on `PATH`
- `python3` **or** `python`, plus `openssl`, `base64`, `curl`

On Git Bash for Windows the harness also needs `cygpath` (ships with Git for
Windows) so it can hand PowerShell native `C:\...` paths instead of MSYS `/c/...`.

## Run
```bash
bash test/e2e.sh        # Issues transport (mock REST API)
bash test/e2e-git.sh    # git transport (local bare repo)
```

`e2e.sh` starts `mock_github.py`, boots the agent (signed then unsigned), drives a
battery of scenarios through `dao-exec.ps1`, and prints `PASS`/`FAIL` per case.
`e2e-git.sh` inits a bare repo, seeds a pre-boot (stale) command, boots
`agent-git.ps1`, and drives commands through `dao-git.sh`. Exit code = failures.

`e2e-git.sh` covers: basic round-trip, multiline, unicode, failure→exit-1+stderr,
wrong-signature rejection, shell metacharacters, and stale-skip (a command seeded
before boot is never executed). It needs no `python` — only git, `openssl`, `base64`.

## What it covers
- happy-path round-trip (signed + unsigned)
- multiline / unicode / triple-backtick / embedded-quote / shell-metachar output (base64 round-trip)
- command failure → non-zero exit + stderr
- empty output
- 60k truncation
- HMAC: wrong secret and unsigned sender both rejected by a signed agent
- backlog: issues created before the agent started are skipped, never executed
- de-dup: every closed issue has exactly one result comment

## Files
- `mock_github.py` — faithful, compact-JSON mock of the endpoints dao uses
  (`/user`, labels, issues list/get, comments, PATCH state) plus `/_control/*`
  helpers (`inject` a pre-dated issue, `reset`, `dump`).

The mock honors `DAO_API`; point the scripts at it with `-ApiBase http://127.0.0.1:8765`.
