# Remote Execution (zero-config)

Run commands on the user's Windows PC - feels like a local shell.

The transport is a **git branch** (`dao-pipe`) in the user's fork: the sender writes
`cmd/<id>`, the agent executes it and writes `res/<id>`. It is plain `git push`/`fetch`,
so a Devin VM needs **no GitHub token** - it already has git access through the built-in
proxy. Nothing to configure.

## Use

```bash
curl -sL https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/dao-exec.sh -o dao-exec.sh && chmod +x dao-exec.sh
./dao-exec.sh "hostname"
./dao-exec.sh "whoami"
./dao-exec.sh "Get-Content C:\\path\\file.txt"
```

stdout = result. Each call blocks until the result returns (default 120s timeout).

## Prerequisite

The user has the agent running on their PC (one line, no PAT):

```powershell
irm https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/agent.ps1 | iex
```

## Signed mode (recommended)

Set the same `DAO_SECRET` on both ends - every command is then HMAC-SHA256 signed and
the agent rejects anything unsigned or forged:

```bash
export DAO_SECRET="shared-secret"      # Devin, before dao-exec.sh
```
```powershell
$env:DAO_SECRET = "shared-secret"      # user, before irm
```

## Config

| Env | Default | Purpose |
|-----|---------|---------|
| `DAO_REPO` | `zhouyoukang1234-spec/devin-remote` | Target repo (the user's fork) |
| `DAO_PIPE` | `dao-pipe` | Branch used as the channel |
| `DAO_SECRET` | _(unset)_ | HMAC-SHA256 key - must match `agent.ps1` |
| `DAO_TIMEOUT` | `120` | Max wait seconds (sender) |
| `DAO_CACHE` | `$HOME/.dao-pipe` / `%USERPROFILE%\.dao-pipe` | Local clone of the pipe branch |
| `DAO_REMOTE` | `https://github.com/<DAO_REPO>.git` | Override the git URL (offline testing) |

## Protocol

- command: `dao1 <base64(cmd)> <hmac-sha256|->`
- result:  `dao1-result <True|False> <ms>\n<base64(output)>`

base64 makes commands/output byte-exact (Unicode, CRLF, shell metacharacters survive).
The agent skips commands created before it booted (no backlog replay) and never re-runs
a command that already has a result.

## Troubleshooting

- **timeout**: agent not running on the user PC, or `DAO_PIPE`/`DAO_REPO` mismatch
- **rejected: invalid/missing signature**: `DAO_SECRET` differs between the two ends
- **skip stale**: agent (re)started after the command was sent - just resend
- **send failed**: the Devin VM cannot push to the repo - confirm the fork exists and
  Devin's git integration has access to it
