# Remote Execution

Execute commands on the user's Windows PC — feels like local shell.

## Quick Start

```bash
# Download dao-exec.sh (one-time)
curl -sL https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/dao-exec.sh -o dao-exec.sh && chmod +x dao-exec.sh

# Execute any command
./dao-exec.sh "hostname"
./dao-exec.sh "dir C:\\Users"
./dao-exec.sh "type C:\\file.txt"
./dao-exec.sh "whoami"
./dao-exec.sh "ipconfig"
./dao-exec.sh "systeminfo | findstr /B /C:OS"
```

Output appears in stdout — block until result returns (default 120s timeout).

## Config

| Env | Default | Purpose |
|-----|---------|---------|
| `DAO_REPO` | `zhouyoukang1234-spec/devin-remote` | Target repo |
| `DAO_TIMEOUT` | `120` | Max wait seconds |
| `DAO_SECRET` | _(unset)_ | HMAC-SHA256 key — must match `agent.ps1` or the command is rejected |
| `DAO_API` | `https://api.github.com` | REST base URL override (GitHub Enterprise / self-test); honored by `agent.ps1` + `dao-exec.ps1` |

When `DAO_SECRET` is set, `dao-exec` signs each command and the agent runs it only if the signature is valid. Leave it unset for zero-config (unsigned) use.

## Prerequisite

User must have `agent.ps1` running on their PC:

```powershell
irm https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/agent.ps1 | iex
```

## Troubleshooting

- **timeout**: agent.ps1 not running on user PC
- **send failed**: `gh auth status` — ensure GitHub CLI is authenticated
- **empty result**: command produced no output (normal for some commands)
- **rejected: invalid/missing signature**: `DAO_SECRET` differs between sender and agent (or set on only one end)
- **skipped: stale command**: agent (re)started after the command was sent — just resend
