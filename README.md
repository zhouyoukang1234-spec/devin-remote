# dao-remote

> A git branch = a transparent transport pipe

Remote command execution between a Devin AI and a user's Windows PC, carried over an
ordinary git branch. Devin sends a command, the PC runs it, the output comes back -
and **neither end needs a GitHub API token or PAT**. GitHub is just the wire.

## Why git (zero-config)

A Devin VM has no direct `api.github.com` token; its only GitHub access is `git push`/`fetch`
through a built-in proxy. So the pipe rides on git itself:

- **Devin side:** no token, no `gh`, no setup - any session/account just runs `dao-exec.sh`.
- **User side:** no PAT - the agent uses the machine's existing git access to the repo.

```
Devin AI (dao-exec.sh)        GitHub: branch dao-pipe        User PC (agent.ps1)
  write cmd/<id> ─ git push ─►  cmd/<id> = base64(command) ─ git fetch ─► run it
  git fetch ◄─ res/<id> ───────  res/<id> = code + base64    ◄─ git push ── write output
```

**Two ends, one pipe. Neither end knows the pipe exists.**

## Wire protocol

| File | Writer | Format |
|------|--------|--------|
| `cmd/<id>` | sender | `base64(command)` |
| `res/<id>` | agent | `<exit-code>` + newline + `base64(output)` |

- **base64** so output with quotes, CRLF, ``` ``` ```` or unicode round-trips byte-exact.
- `<id>` = `<unix-ms>-<rand>`: just a unique name.
- **Clock-free:** at startup the agent records which commands already exist and ignores them,
  then runs only commands that appear afterwards. No timestamps, so two machines' clocks can
  never disagree (and a reconnecting agent never replays a backlog).

## Files

| File | End | Role |
|------|-----|------|
| `dao-exec.sh` | Devin VM (Linux) | Sender - zero-config, no GitHub token |
| `agent.ps1` | User PC (Windows) | Receiver - uses the machine's own git creds, no PAT |
| `_Devin.md` | Devin AI | Usage instructions (what Devin reads) |
| `test/e2e.sh` | local | Offline end-to-end harness (a local bare repo stands in for GitHub) |

## Setup

**1. User PC - one line:**

```powershell
irm https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/agent.ps1 | iex
```

Runs on Windows PowerShell 5.1 (Desktop) and PowerShell 7+ (Core). Needs Git for Windows
on `PATH`. If the machine has no git credentials yet, Git's own helper prompts a one-time
browser sign-in the first time the agent pushes output - no hand-made PAT.

Behind a proxy/VPN, the agent automatically routes git through the same proxy the OS uses
(git ignores the system proxy by default), and prints a clear error at startup if git still
can't reach the repo - so it never just hangs silently.

**2. Devin AI - one command:**

```bash
curl -sL https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/dao-exec.sh -o dao-exec.sh && chmod +x dao-exec.sh
./dao-exec.sh "hostname"
```

**3. Other users:** fork this repo, then set `DAO_REPO=yourname/devin-remote` on both ends.

## Config

| Env | Default | Purpose |
|-----|---------|---------|
| `DAO_REPO` | `zhouyoukang1234-spec/devin-remote` | Target repo |
| `DAO_PIPE` | `dao-pipe` | Branch used as the channel |
| `DAO_TIMEOUT` | `120` | Max wait seconds (sender) |
| `DAO_POLL` | `3` | Agent poll interval seconds |
| `DAO_CACHE` | `$HOME/.dao-pipe` / `%USERPROFILE%\.dao-pipe` | Local clone of the pipe branch |
| `DAO_REMOTE` | `https://github.com/<DAO_REPO>.git` | Override the git URL (offline testing) |

## Verified

- **Offline** `test/e2e.sh` (local bare repo as GitHub, no network): basic, multiline,
  unicode (`道法自然`), failure-code propagation, shell metacharacters byte-exact, baseline skip.
- **Live**, against this repo through the Devin git proxy with **no GitHub token**:
  `hostname`, unicode `道法自然`, metacharacters, failure codes - all returned.

## Security

The boundary is GitHub access: only someone who can sign in to the account can write commands
to (or read output from) the repo. That's it - no extra keys to manage. Keep the repo to
accounts you trust; the pipe history is a plain audit trail of commands and outputs.

## Philosophy

- **Transport layer, not system** - a git branch is a pipe, not an application
- **Transparent** - neither end knows the pipe exists
- **Zero-config** - each end reuses the git access it already has; nothing to authenticate
- **无为而无不为** - the pipe does nothing itself; it only carries
