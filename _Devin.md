# Remote Execution

Execute commands on the user's Windows PC - feels like local shell.

There are two transports. **Prefer git** - it needs no GitHub token on the Devin
side, so any Devin session (any account) plugs in with zero configuration.

---

## Transport A - git pipe (recommended, zero-config)

A data-only orphan branch (`dao-pipe`) is the channel. The sender writes `cmd/<id>`,
the agent executes it and writes `res/<id>`. It uses **only `git push`/`fetch`**, so:

- **Devin side: nothing to set up.** A Devin VM already has git access to the user's
  repo through the built-in git proxy. No PAT, no `gh`, no API token. Just run:

  ```bash
  curl -sL https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/dao-git.sh -o dao-git.sh && chmod +x dao-git.sh
  ./dao-git.sh "hostname"
  ./dao-git.sh "whoami"
  ./dao-git.sh "Get-Content C:\\path\\file.txt"
  ```

- **User side: one line, no PAT.** The agent uses the machine's existing git
  credentials for the user's own fork (if they cloned/forked it, they already have
  this). One-time start:

  ```powershell
  irm https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/agent-git.ps1 | iex
  ```

  If a machine has no git credentials at all, git's own helper will prompt a one-time
  browser sign-in (Git Credential Manager device/OAuth flow) - no hand-made PAT.

### git-pipe config

| Env | Default | Purpose |
|-----|---------|---------|
| `DAO_REPO` | `zhouyoukang1234-spec/devin-remote` | Target repo |
| `DAO_PIPE` | `dao-pipe` | Branch used as the channel |
| `DAO_SECRET` | _(unset)_ | HMAC-SHA256 key - must match `agent-git.ps1` or the command is rejected |
| `DAO_TIMEOUT` | `120` | Max wait seconds (sender) |
| `DAO_CACHE` | `$HOME/.dao-pipe` (sender) / `%USERPROFILE%\.dao-pipe` (agent) | Local working clone of the pipe branch |
| `DAO_REMOTE` | `https://github.com/<DAO_REPO>.git` | Override the git URL (offline testing) |

---

## Transport B - GitHub Issues (REST API)

Issues carry the command, comments carry the result. Human-auditable, but the **Devin
side needs a GitHub API token** (`gh`/PAT/env), so it is not zero-config on a Devin VM.
Use it when you want the exchange visible as Issues, or already have a token.

```bash
curl -sL https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/dao-exec.sh -o dao-exec.sh && chmod +x dao-exec.sh
./dao-exec.sh "hostname"
```

User side:

```powershell
irm https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/agent.ps1 | iex
```

| Env | Default | Purpose |
|-----|---------|---------|
| `DAO_REPO` | `zhouyoukang1234-spec/devin-remote` | Target repo |
| `DAO_TIMEOUT` | `120` | Max wait seconds |
| `DAO_SECRET` | _(unset)_ | HMAC-SHA256 key - must match `agent.ps1` |
| `DAO_API` | `https://api.github.com` | REST base URL override (GitHub Enterprise / self-test) |

---

## Protocol (shared by both transports)

- command: `dao1 <base64(cmd)> <hmac-sha256|->`
- result:  `dao1-result <True|False> <ms>\n<base64(output)>`

base64 makes commands/output byte-exact (Unicode, CRLF, shell metacharacters all
survive). When `DAO_SECRET` is set, the sender signs and the agent runs the command
only if the HMAC verifies. Leave it unset for zero-config (unsigned) use. The agent
skips commands created before it booted (no backlog replay) and is idempotent (a
command already answered is never re-run).

## Troubleshooting

- **timeout**: agent not running on user PC, or `DAO_PIPE`/`DAO_REPO` mismatch
- **rejected: invalid/missing signature**: `DAO_SECRET` differs between sender and agent
- **skip stale**: agent (re)started after the command was sent - just resend
- **git pipe: send failed**: the Devin VM cannot push to the repo - confirm the repo
  exists and Devin's git integration has access to it
