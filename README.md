# dao-remote

> GitHub Issues = transparent transport pipe

Remote command execution via GitHub Issues.
Devin AI sends commands, user PC executes them.
The pipe is invisible to both ends.

## Architecture

```
Devin AI              GitHub (pipe)              User PC
dao-exec "cmd"  →  Issue: dao1 <b64> <sig>  →  agent.ps1 polls
                 ←  Comment: dao1-result    ←  verify sig, exec, post base64
stdout = result  ←  Issue closed            ←
```

**Two ends, one pipe. Neither end knows the pipe exists.**

### Two transports, one protocol

The same `dao1` envelope rides over either carrier:

| Transport | Carrier | Devin-side auth | When |
|-----------|---------|-----------------|------|
| **git pipe** (recommended) | `dao-pipe` branch: `cmd/<id>` + `res/<id>` files | **none** - reuses the Devin VM's built-in git proxy, no token | any Devin/account plugs in zero-config |
| Issues | Issue body + comment | a GitHub API token (`gh`/PAT/env) | when you want a human-visible Issue trail |

A Devin VM can `git push`/`fetch` the user's repo through its proxy but has **no**
direct `api.github.com` token, so the git pipe is what makes onboarding truly
zero-config. See `_Devin.md`.

### Wire protocol (v1 / `dao1`)

| Direction | Carrier | Format |
|-----------|---------|--------|
| command   | Issue body | `dao1 <base64(cmd)> <hmac-sha256(b64)\|->` |
| result    | last comment | `dao1-result <True\|False> <ms>` + newline + `base64(output)` |

- **base64**, not markdown fences — output containing ```` ``` ````, quotes, CRLF, or unicode round-trips byte-exact.
- **HMAC-SHA256** envelope signing (opt-in via `DAO_SECRET`) — agent refuses commands without a valid signature, so a private repo is no longer the *only* line of defense against an attacker who can open issues.

## Files

| File | End | Role |
|------|-----|------|
| `dao-git.sh` | Devin VM (Linux) | **git-pipe sender** — zero-config, no GitHub token (uses git proxy) |
| `agent-git.ps1` | User PC (Windows) | **git-pipe receiver** — uses the machine's own git creds, no PAT |
| `dao-exec.sh` | Devin VM (Linux) | Issues sender — one command, stdout = result (needs `gh`) |
| `dao-exec.ps1` | Windows (testing) | Same, for local testing without gh CLI |
| `agent.ps1` | User PC (Windows) | Issues receiver — auto-auth token chain |
| `_Devin.md` | Devin AI | Usage instructions (this is what Devin reads) |

## Setup

### 0. git transport — zero-config (recommended)

User PC (uses the machine's existing git access to the fork — no PAT):

```powershell
irm https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/agent-git.ps1 | iex
```

Devin AI (no token, works in any session via the git proxy):

```bash
curl -sL https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/dao-git.sh -o dao-git.sh && chmod +x dao-git.sh
./dao-git.sh "hostname"
```

Set `DAO_SECRET` on both ends for HMAC-signed mode. The sections below describe the
alternative Issues transport (REST API, needs a Devin-side token).

### 1. User PC — one command (Issues transport)

```powershell
irm https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/agent.ps1 | iex
```

Auto-auth chain (zero user input):

1. **Windows Credential Manager** — reads git's stored PAT (most reliable)
2. **gh CLI** — `gh auth token`
3. **Environment variables** — `DAO_TOKEN` / `GITHUB_TOKEN`
4. **.git-credentials** — file parsing
5. **Device Flow** — last resort, one-time browser authorization, auto-saved

Auto-proxy: detects local proxy (7897, 7890, 10808, 1080, 2080) or reads `HTTPS_PROXY` env.

**Signed mode (recommended):** set `DAO_SECRET` on both ends — the agent then requires a valid HMAC on every command:

```powershell
$env:DAO_SECRET = "your-shared-secret"
irm https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/agent.ps1 | iex
```

Without `DAO_SECRET` the agent runs in unsigned mode (zero-config, prints a warning).

**Custom API host (GitHub Enterprise / testing):** set `DAO_API` to override the REST base URL (default `https://api.github.com`). Both `agent.ps1` and `dao-exec.ps1` honor it, e.g. `$env:DAO_API = "https://ghe.example.com/api/v3"`. The Linux sender `dao-exec.sh` uses the `gh` CLI, so point it at an enterprise host with `gh`'s own `GH_HOST`.

**PowerShell support:** runs on both Windows PowerShell 5.1 (Desktop) and PowerShell 7+ (Core, incl. Linux/macOS) — the assemblies needed for proxy support are referenced conditionally per edition.

### 2. Devin AI — one command

```bash
# Install (one-time)
curl -sL https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/dao-exec.sh -o dao-exec.sh && chmod +x dao-exec.sh

# Execute
./dao-exec.sh "hostname"
```

### 3. Fork for other users

Fork this repo → set `DAO_REPO=yourname/devin-remote` → done.

## Verified

| Command | Result | Status |
|---------|--------|--------|
| `hostname` | `DESKTOP-MASTER` | OK |
| `whoami` | `desktop-master\administrator` | OK |
| `echo hello dao` | `hello dao` | OK |

Protocol/hardening also verified via real GitHub round-trips (signed exec, signature rejection, triple-backtick/unicode output round-trip, restart de-dup).

**git transport** verified end-to-end: offline harness (`test/e2e-git.sh`, 8/8 — basic, multiline, unicode, failure path, signature rejection, metacharacters, stale-skip) and a live signed round-trip against this repo through the Devin git proxy with **no GitHub token** (`hostname`, `$env:USERNAME`, unicode `道法自然`, arithmetic all returned).

## Hardening notes

- **One agent per repo.** Running two agents against the same repo can double-execute a command; the design assumes a single receiver.
- **Skip-on-restart.** The agent ignores commands created before it booted, so reconnecting never replays a backlog.
- **Least-privilege token.** Prefer a fine-grained PAT scoped to *only this repo's Issues (read/write)* over a classic `repo`-scoped token.
- **Audit trail.** Every command + output stays in closed Issues. Treat the repo as a command log and prune periodically; signed mode keeps the contents authenticated but not secret.

## Philosophy

- **Transport layer, not system** — GitHub Issues is a pipe, not an application
- **Transparent** — neither end knows the pipe exists
- **dao-exec is a tap** — turn it on, water flows through the pipe and back
- **agent.ps1 is a drain** — receives water, processes it, sends it back
- **无为无以为** — the pipe does nothing itself; it only carries
