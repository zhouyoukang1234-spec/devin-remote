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
| `dao-exec.sh` | Devin VM (Linux) | Transparent sender — one command, stdout = result |
| `dao-exec.ps1` | Windows (testing) | Same, for local testing without gh CLI |
| `agent.ps1` | User PC (Windows) | Transparent receiver — auto-auth, zero config |
| `_Devin.md` | Devin AI | Usage instructions (this is what Devin reads) |

## Setup

### 1. User PC — one command

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
| `hostname` | `DESKTOP-MASTER` | ✓ |
| `whoami` | `desktop-master\administrator` | ✓ |
| `echo hello dao` | `hello dao` | ✓ |

Protocol/hardening also verified via real GitHub round-trips (signed exec, signature rejection, triple-backtick/unicode output round-trip, restart de-dup).

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
