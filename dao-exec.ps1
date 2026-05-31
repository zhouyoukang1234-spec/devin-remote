<#
dao-exec — transparent remote command execution (Windows)
GitHub Issues = invisible transport pipe
Usage: dao-exec "command" → stdout = result (feels like local execution)
#>
param([string]$Repo = "zhouyoukang1234-spec/devin-remote", [Parameter(Mandatory)][string]$Command)
$LABEL = "devin-cmd"

# Send: create Issue = push command into pipe
$num = & gh issue create --repo $Repo --label $LABEL --title cmd --body $Command 2>$null |
       Select-String '\d+$' | ForEach-Object { $_.Matches[0].Value }
if (-not $num) { Write-Host "dao: send failed (gh auth ok? repo exists?)" -F Red; exit 1 }

# Receive: poll until closed = result came back through pipe
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep 3
  $state = & gh issue view $num --repo $Repo --json state -q .state 2>$null
  if ($state -eq 'CLOSED') {
    $body = & gh issue view $num --repo $Repo --comments --json comments -q '.comments[-1].body' 2>$null
    # Extract output from code block
    $inBlock = $false; $output = @()
    foreach ($line in $body -split "`n") {
      if ($line -eq '```') { $inBlock = -not $inBlock; continue }
      if ($inBlock) { $output += $line }
    }
    $output -join "`n"
    exit 0
  }
}
Write-Host "dao: timeout 120s — agent.ps1 running on user PC?" -F Red; exit 1
