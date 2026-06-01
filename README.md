# dao-remote

> A git branch = transparent transport pipe

Remote command execution between a Devin AI and a user's Windows PC, carried over an
ordinary git branch. Devin sends a command, the PC executes it, the output comes back -
and **neither end needs a GitHub API token**.

## Why git (zero-config)

A Devin VM has no direct `api.github.com` token; its only GitHub access is `git push`/`fetch`
through a built-in proxy. So the pipe rides on git itself:

- **Devin side:** no token, no `gh`, no setup - any session/account just runs `dao-exec.sh`.
- **User side:** no PAT - the agent uses the machine's existing git access to the user's own fork.

```
Devin AI (dao-exec.sh)        GitHub: branch dao-pipe          User PC (agent.ps1)
  write cmd/<id> ─ git push ─►  cmd/<id> = dao1 <b64> <sig>  ─ git fetch ─► verify + exec
  git fetch ◄─ res/<id> ───────  res/<id> = dao1-result …    ◄─ git push ── write result
```

**Two ends, one pipe. Neither end knows the pipe exists.**

## Wire protocol (`dao1`)

| File | Writer | Format |
|------|--------|--------|
| `cmd/<id>` | sender | `dao1 <base64(cmd)> <hmac-sha256(b64)\|->` |
| `res/<id>` | agent | `dao1-result <True\|False> <ms>` + newline + `base64(output)` |

- **base64**, not markdown - output with quotes, CRLF, ``` ``` ```` or unicode round-trips byte-exact.
- **HMAC-SHA256** signing (opt-in via `DAO_SECRET`) - the agent refuses commands without a valid signature. Default is unsigned/zero-config: the security boundary is simply GitHub access to the private repo (only the account owner can read or write the pipe).
- `<id>` = `<unix-ms>-<rand>`: sortable, and lets the agent skip commands created before it booted.

## Files

| File | End | Role |
|------|-----|------|
| `dao-exec.sh` | Devin VM (Linux) | Sender - zero-config, no GitHub token |
| `agent.ps1` | User PC (Windows) | Receiver - uses the machine's own git creds, no PAT |
| `_Devin.md` | Devin AI | Usage instructions (what Devin reads) |
| `test/e2e.sh` | CI / local | Offline end-to-end harness (a local bare repo stands in for GitHub) |

## Setup

Both sides fetch over **authenticated git**, not anonymous HTTP - so it works on **private**
repos with nothing but the GitHub access each side already has (a raw
`https://raw.githubusercontent.com/...` download would 404 on a private repo).

**1. User PC - one line** (uses the machine's existing git access; clones to `~/.devin-remote`,
self-updates on each run, then starts the agent):

```powershell
$d="$HOME\.devin-remote"; if(Test-Path "$d\.git"){git -C $d fetch -q origin main; git -C $d reset -q --hard FETCH_HEAD}else{git clone -q https://github.com/zhouyoukang1234-spec/devin-remote $d}; iex(Get-Content "$d\agent.ps1" -Raw)
```

Runs on Windows PowerShell 5.1 (Desktop) and PowerShell 7+ (Core). Needs Git for Windows
on `PATH`. If the machine has no git credentials yet, Git's own helper prompts a one-time
browser sign-in - no hand-made PAT. Optional signed mode: `$env:DAO_SECRET="shared-secret"`
before the line above (set the same on the Devin side).

**2. Devin AI - one command** (clones via the built-in git proxy, self-updates, then sends):

```bash
d=~/.devin-remote; if [ -d "$d/.git" ]; then git -C "$d" fetch -q origin main && git -C "$d" reset -q --hard origin/main; else git clone -q https://github.com/zhouyoukang1234-spec/devin-remote "$d"; fi; "$d/dao-exec.sh" "hostname"
```

**3. Other users:** fork this repo, then set `DAO_REPO=yourname/devin-remote` on both ends
(and the repo URL in the two commands above).

## Config

| Env | Default | Purpose |
|-----|---------|---------|
| `DAO_REPO` | `zhouyoukang1234-spec/devin-remote` | Target repo (the user's fork) |
| `DAO_PIPE` | `dao-pipe` | Branch used as the channel |
| `DAO_SECRET` | _(unset)_ | HMAC-SHA256 key - must match on both ends |
| `DAO_TIMEOUT` | `120` | Max wait seconds (sender) |
| `DAO_CACHE` | `$HOME/.dao-pipe` / `%USERPROFILE%\.dao-pipe` | Local clone of the pipe branch |
| `DAO_REMOTE` | `https://github.com/<DAO_REPO>.git` | Override the git URL (offline testing) |

## Verified

- **Offline** `test/e2e.sh` (local bare repo as GitHub, no network): basic, multiline,
  unicode (`道法自然`), failure→exit-1+stderr, wrong-signature rejection, shell
  metacharacters byte-exact, stale-skip.
- **Live**, against this repo through the Devin git proxy with **no GitHub token**, signed:
  `hostname`, `$env:USERNAME`, unicode `道法自然`, arithmetic - all returned.

## Hardening

- **One agent per repo.** Two agents on the same repo could double-execute; the design assumes one receiver.
- **Skip-on-restart.** The agent ignores commands created before it booted, so reconnecting never replays a backlog.
- **Idempotent.** A command that already has a `res/<id>` is never re-run.
- **Audit trail.** Every command + output stays in the `dao-pipe` branch history; signed mode keeps it authenticated, not secret. Prune the branch periodically.

## Philosophy

- **Transport layer, not system** - a git branch is a pipe, not an application
- **Transparent** - neither end knows the pipe exists
- **Zero-config** - each end reuses the git access it already has; nothing to authenticate
- **无为而无不为** - the pipe does nothing itself; it only carries
