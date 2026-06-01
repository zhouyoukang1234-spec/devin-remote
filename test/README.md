# Local end-to-end test harness

Runs the **real** `agent.ps1` (receiver) and `dao-exec.ps1` (sender) against a
local in-memory mock of the GitHub Issues API, so the full transport pipe can be
exercised offline — no real GitHub repo, token, or network required. This is how
the pipe is validated in sandboxes where `api.github.com` is unreachable.

## Requirements
- `pwsh` (PowerShell 7+) **or** Windows PowerShell 5.1 (`powershell.exe`) — the
  harness auto-detects whichever is on `PATH`
- `python3` **or** `python`, plus `openssl`, `base64`, `curl`

On Git Bash for Windows the harness also needs `cygpath` (ships with Git for
Windows) so it can hand PowerShell native `C:\...` paths instead of MSYS `/c/...`.

## Run
```bash
bash test/e2e.sh
```

It starts `mock_github.py`, boots the agent (signed then unsigned), drives a
battery of scenarios through `dao-exec.ps1`, and prints `PASS`/`FAIL` per case.
Exit code = number of failures.

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
