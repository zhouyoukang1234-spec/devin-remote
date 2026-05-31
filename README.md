# dao-remote

> GitHub Issues = transparent transport pipe

Remote command execution via GitHub Issues.
Devin AI sends commands, user PC executes them.
The pipe is invisible to both ends.

## Architecture

```
Devin AI              GitHub (pipe)              User PC
dao-exec "cmd"  →  Issue created     →  agent.ps1 polls
                 ←  Comment posted    ←  executes, posts result
stdout = result  ←  Issue closed     ←
```

**Two ends, one pipe. Neither end knows the pipe exists.**

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

## Philosophy

- **Transport layer, not system** — GitHub Issues is a pipe, not an application
- **Transparent** — neither end knows the pipe exists
- **dao-exec is a tap** — turn it on, water flows through the pipe and back
- **agent.ps1 is a drain** — receives water, processes it, sends it back
- **无为无以为** — the pipe does nothing itself; it only carries
