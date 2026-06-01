# Remote Execution (zero-config)

Run commands on the user's Windows PC - feels like a local shell.

The transport is a **git branch** (`dao-pipe`): the sender writes `cmd/<id>`, the agent
runs it and writes `res/<id>`. It is plain `git push`/`fetch`, so a Devin VM needs **no
GitHub token** - it already has git access through the built-in proxy. Nothing to configure.

## Use

```bash
curl -sL https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/dao-exec.sh -o dao-exec.sh && chmod +x dao-exec.sh
./dao-exec.sh "hostname"
./dao-exec.sh "whoami"
./dao-exec.sh "Get-Content C:\\path\\file.txt"
```

stdout = the command's output; exit code propagates. Each call blocks until the result
returns (default 120s timeout).

## Prerequisite

The user has the agent running on their PC (one line, no PAT):

```powershell
irm https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/agent.ps1 | iex
```

## Config

| Env | Default | Purpose |
|-----|---------|---------|
| `DAO_REPO` | `zhouyoukang1234-spec/devin-remote` | Target repo |
| `DAO_PIPE` | `dao-pipe` | Branch used as the channel |
| `DAO_TIMEOUT` | `120` | Max wait seconds (sender) |
| `DAO_CACHE` | `$HOME/.dao-pipe` / `%USERPROFILE%\.dao-pipe` | Local clone of the pipe branch |
| `DAO_REMOTE` | `https://github.com/<DAO_REPO>.git` | Override the git URL (offline testing) |

## Protocol

- command: `cmd/<id>` = `base64(command)`
- result:  `res/<id>` = `<exit-code>` + newline + `base64(output)`

base64 keeps commands/output byte-exact (Unicode, CRLF, shell metacharacters survive).
The agent is **clock-free**: at startup it records which commands already exist and ignores
them, then runs only commands that appear afterwards - so clocks never disagree, a
reconnecting agent never replays a backlog, and a command with a result is never re-run.

## Troubleshooting

- **timeout**: agent not running on the user PC, or `DAO_PIPE`/`DAO_REPO` mismatch. If the
  agent was started *after* you sent a command, that command is treated as pre-existing
  (baseline) and skipped - just send again.
- **send failed**: the Devin VM cannot push to the repo - confirm the repo exists and
  Devin's git integration has access to it.
