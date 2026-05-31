# Remote Execution

Use `dao-exec "command"` to execute commands on the user's Windows PC.

```bash
dao-exec "hostname"           # get PC hostname
dao-exec "dir C:\\Users"      # list directory
dao-exec "type C:\\file.txt"  # read file
dao-exec "whoami"             # current user
```

Output appears in your terminal — feels like local execution.

**Prerequisite**: user must have `agent.ps1` running on their PC.

**Config**: `DAO_REPO=owner/devin-remote` (default: zhouyoukang1234-spec/devin-remote)
