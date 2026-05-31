# dao - devin-remote

> One line to remote PowerShell control

## Architecture - GitHub is the hub

```
GitHub (hub - permanent)
  Issues = command queue
    open  = pending
    closed = done
    comment = result
  agent.ps1
  _Devin.md
```

No cloudflared, no hub.js, no Node.js, no WebSocket. GitHub Issues is the natural bidirectional command queue.

## Usage

### 1. Fork this repo

### 2. User PC (one command)

```powershell
irm https://raw.githubusercontent.com/{user}/devin-remote/main/agent.ps1 | iex
```

Enter repo name + PAT (needs `repo` scope).

### 3. Devin AI controls

```bash
gh issue create --repo {user}/devin-remote --label devin-cmd --body "dir C:\\Users"
gh issue view {number} --repo {user}/devin-remote --comments
```

## dao

> The way is to subtract, subtract and subtract again, until鏃犱负, and鏃犱负鑰屾棤涓嶄负.

hub.js - eliminated (GitHub API replaces)
setup.sh - eliminated (no Devin VM deployment needed)
cloudflared - eliminated (GitHub is public)
WebSocket - eliminated (Issues polling replaces)
Node.js - eliminated (pure PowerShell)
Ed25519 - eliminated (GitHub native auth)

Only the essence remains: **PowerShell + GitHub Issues + remote command execution**.