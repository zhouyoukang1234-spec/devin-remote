# dao agent.ps1 - GitHub Issues = command queue - 0 deps
# Usage: irm https://raw.githubusercontent.com/{user}/devin-remote/main/agent.ps1 | iex
param(
  [string]$Repo = "",
  [string]$Token = ""
)

$LABEL = "devin-cmd"
$POLL_SEC = 3

if (-not $Repo) {
  Write-Host ""
  Write-Host "  dao - remote exec" -ForegroundColor Cyan
  $Repo = Read-Host "  GitHub repo (e.g. zhouyoukang1234-spec/devin-remote)"
}
if (-not $Token) {
  $Token = Read-Host "  GitHub PAT (repo scope)"
  if (-not $Token) {
    try {
      $cred = "protocol=https`nhost=github.com`n" | git credential fill 2>$null
      if ($cred -match "password=(.+)") { $Token = $Matches[1] }
    } catch {}
  }
}
if (-not $Repo -or -not $Token) {
  Write-Host "[dao] missing repo or token" -ForegroundColor Red
  exit 1
}

$Headers = @{
  "Authorization" = "Bearer $Token"
  "Accept" = "application/vnd.github+json"
  "X-GitHub-Api-Version" = "2022-11-28"
  "Content-Type" = "application/json"
  "User-Agent" = "dao-remote/1"
}
$ApiBase = "https://api.github.com/repos/$Repo"

Write-Host ""
try {
  $me = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $Headers -Method Get
  Write-Host "[dao] GitHub: $($me.login) OK" -ForegroundColor Green
} catch {
  Write-Host "[dao] Token invalid: $_" -ForegroundColor Red
  exit 1
}

try {
  Invoke-RestMethod -Uri "$ApiBase/labels/$LABEL" -Headers $Headers -Method Get | Out-Null
} catch {
  try {
    Invoke-RestMethod -Uri "$ApiBase/labels" -Headers $Headers -Method Post -Body (@{name=$LABEL;color="0075ca"} | ConvertTo-Json) | Out-Null
    Write-Host "[dao] created label: $LABEL" -ForegroundColor Yellow
  } catch {}
}

Write-Host "[dao] polling $Repo ... (Ctrl+C to exit)" -ForegroundColor Cyan
Write-Host ""

$processedIds = @{}

while ($true) {
  try {
    $issues = Invoke-RestMethod -Uri "$ApiBase/issues?labels=$LABEL&state=open&per_page=10" -Headers $Headers -Method Get
    foreach ($issue in $issues) {
      $id = $issue.number
      if ($processedIds.ContainsKey($id)) { continue }
      $processedIds[$id] = $true
      $cmd = $issue.body
      if (-not $cmd) { continue }
      Write-Host "[dao] #$id exec: $cmd" -ForegroundColor Yellow
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      try {
        $output = cmd /c $cmd 2>&1 | Out-String
        $ok = $true
      } catch {
        $output = $_.Exception.Message
        $ok = $false
      }
      $sw.Stop()
      if ($output.Length -gt 60000) {
        $output = $output.Substring(0, 60000) + "`n... (truncated, total $($output.Length) chars)"
      }
      $result = "`n**Result** ($($sw.ElapsedMilliseconds)ms) ``$ok```n`````n$output``````n"
      try {
        Invoke-RestMethod -Uri "$ApiBase/issues/$id/comments" -Headers $Headers -Method Post -Body (@{body=$result} | ConvertTo-Json) | Out-Null
      } catch {
        Write-Host "[dao] #$id send result failed: $_" -ForegroundColor Red
      }
      try {
        Invoke-RestMethod -Uri "$ApiBase/issues/$id" -Headers $Headers -Method Patch -Body (@{state="closed"} | ConvertTo-Json) | Out-Null
      } catch {}
      Write-Host "[dao] #$id done ($($sw.ElapsedMilliseconds)ms)" -ForegroundColor Green
    }
  } catch {}
  Start-Sleep $POLL_SEC
}