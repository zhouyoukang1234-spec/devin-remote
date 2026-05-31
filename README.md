# dao-remote

> GitHub Issues = transparent transport pipe
> 抛绣还是那个抛绣，只是路由变了

Remote command execution via GitHub Issues. Devin AI sends commands, user PC executes them. The pipe is invisible to both ends.

## Architecture

```
Devin AI              GitHub (pipe)              User PC
dao-exec "cmd"  →  Issue created     →  agent.ps1 polls
                 ←  Comment posted    ←  executes, posts result
stdout = result  ←  Issue closed     ←
```

## Two ends, one pipe

| End | File | Role |
|-----|------|------|
| Devin VM (Linux) | `dao-exec.sh` | Transparent sender — feels like local execution |
| User PC (Windows) | `agent.ps1` | Transparent receiver — auto-auth, zero config |
| Windows (testing) | `dao-exec.ps1` | Same, for local testing |

## Setup

### 1. User PC (one command)

```powershell
irm https://raw.githubusercontent.com/{user}/devin-remote/main/agent.ps1 | iex
```

Auto-auth chain: gh CLI → env vars → git-credentials → Device Flow (one-time, auto-saved).

### 2. Devin AI (one command)

```bash
dao-exec "hostname"
```

That's it. Output appears in stdout.

### 3. Fork for other users

Fork this repo → set `DAO_REPO=yourname/devin-remote` → done.

## Philosophy

- **Transport layer, not system** — GitHub Issues is a pipe, not an application
- **Transparent** — neither end knows the pipe exists
- **dao-exec is a water tap** — turn it on, water flows through the pipe and back
- **agent.ps1 is a drain** — receives water, processes it, sends it back
- **无为无以为** — the pipe does nothing itself; it only carries
