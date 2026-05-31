<#
dao agent - GitHub Issues transport - 0 deps - Device Flow auth
Usage: irm https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/agent.ps1 | iex
#>
param(
  [string]$Repo  = "zhouyoukang1234-spec/devin-remote",
  [string]$Token = ""
)

$LABEL = "devin-cmd"
$CLIENT_ID = "178c6fc778ccc68e1d6a"  # GitHub CLI OAuth App (public, Device Flow)

# ── Auto proxy ──
$Proxy = ""
$proxyEnv = $env:HTTPS_PROXY, $env:HTTP_PROXY | Where-Object { $_ } | Select-Object -First 1
if ($proxyEnv) { $Proxy = $proxyEnv }
else {
  foreach ($port in 7890, 7897, 1080, 10808, 10809, 2080) {
    try { $c = New-Object Net.Sockets.TcpClient("127.0.0.1", $port)
          if ($c.Connected) { $Proxy = "http://127.0.0.1:$port"; $c.Close(); break } } catch {}
  }
}

function dao-api($uri, $method="Get", $body=$null) {
  $splat = @{ Uri=$uri; Headers=$script:Headers; Method=$method; ErrorAction="Stop" }
  if ($Proxy) { $splat.Proxy = $Proxy }
  if ($body) { $splat.Body = $body; $splat.ContentType = "application/json" }
  return Invoke-RestMethod @splat
}

# ── Auto token ──
if (-not $Token) {
  # 1. Env vars
  if ($env:DAO_TOKEN) { $Token = $env:DAO_TOKEN }
  elseif ($env:GITHUB_TOKEN) { $Token = $env:GITHUB_TOKEN }
  # 2. .git-credentials
  elseif (Test-Path "$env:USERPROFILE\.git-credentials") {
    $gc = Get-Content "$env:USERPROFILE\.git-credentials" -ErrorAction SilentlyContinue |
          Where-Object { $_ -match 'github\.com' } | Select-Object -First 1
    if ($gc -match ':([^:@]+)@github') { $Token = $Matches[1] }
  }
  # 3. git credential
  if (-not $Token) {
    try {
      $cf = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
      if ($cf -match "password=(.+)") { $Token = $Matches[1] }
    } catch {}
  }
}

# ── Verify existing token ──
if ($Token) {
  $script:Headers = @{
    "Authorization" = "Bearer $Token"
    "Accept" = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "Content-Type" = "application/json"
    "User-Agent" = "dao/1"
  }
  try {
    $me = dao-api "https://api.github.com/user"
    Write-Host "[dao] $($me.login) @ $Repo$(if($Proxy){' (proxy)'})" -ForegroundColor Green
    $Token | Out-Null  # valid
  } catch {
    Write-Host "[dao] saved token invalid, starting Device Flow..." -ForegroundColor Yellow
    $Token = ""  # fall through to Device Flow
  }
}

# ── Device Flow (zero paste) ──
if (-not $Token) {
  Write-Host ""
  Write-Host "  dao · Device Flow" -ForegroundColor Cyan
  Write-Host "  ─────────────────" -ForegroundColor DarkGray

  # Step 1: Start device flow
  $dfHeaders = @{ "Accept" = "application/vnd.github+json"; "Content-Type" = "application/json" }
  $dfBody = '{"client_id":"' + $CLIENT_ID + '","scope":"repo"}'
  $dfSplat = @{ Uri="https://github.com/login/device/code"; Method="Post"; Body=$dfBody; Headers=$dfHeaders; ErrorAction="Stop"; ContentType="application/json" }
  if ($Proxy) { $dfSplat.Proxy = $Proxy }

  try {
    $df = Invoke-RestMethod @dfSplat
  } catch {
    # Fallback: use GitHub CLI if available
    if (Get-Command gh -ErrorAction SilentlyContinue) {
      Write-Host "[dao] using gh CLI for auth..." -ForegroundColor Yellow
      & gh auth login --hostname github.com --git-protocol https --web 2>&1 | Write-Host
      $ghToken = & gh auth token 2>$null
      if ($ghToken -and $ghToken -notmatch 'error') {
        $Token = $ghToken.Trim()
        $script:Headers = @{
          "Authorization" = "Bearer $Token"
          "Accept" = "application/vnd.github+json"
          "X-GitHub-Api-Version" = "2022-11-28"
          "Content-Type" = "application/json"
          "User-Agent" = "dao/1"
        }
        $me = dao-api "https://api.github.com/user"
        Write-Host "[dao] $($me.login) @ $Repo" -ForegroundColor Green
      }
    }
    if (-not $Token) {
      Write-Host "[dao] Device Flow failed. Set env DAO_TOKEN=ghp_xxx and retry." -ForegroundColor Red
      exit 1
    }
  }

  if ($df) {
    Write-Host ""
    Write-Host "  Open: $($df.verification_uri)" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "  Code: $($df.user_code)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Waiting for authorization..." -ForegroundColor Gray

    # Step 2: Poll for token
    $interval = $df.interval
    $deadline = (Get-Date).AddSeconds($df.expires_in)
    $pollHeaders = @{ "Accept" = "application/vnd.github+json"; "Content-Type" = "application/json" }

    while ((Get-Date) -lt $deadline) {
      Start-Sleep $interval
      $pollBody = '{"client_id":"' + $CLIENT_ID + '","device_code":"' + $df.device_code + '"}'
      $pollSplat = @{ Uri="https://github.com/login/oauth/access_token"; Method="Post"; Body=$pollBody; Headers=$pollHeaders; ErrorAction="Stop"; ContentType="application/json" }
      if ($Proxy) { $pollSplat.Proxy = $Proxy }

      try {
        $poll = Invoke-RestMethod @pollSplat
        if ($poll.access_token) {
          $Token = $poll.access_token
          $script:Headers = @{
            "Authorization" = "Bearer $Token"
            "Accept" = "application/vnd.github+json"
            "X-GitHub-Api-Version" = "2022-11-28"
            "Content-Type" = "application/json"
            "User-Agent" = "dao/1"
          }
          $me = dao-api "https://api.github.com/user"
          Write-Host "[dao] $($me.login) @ $Repo$(if($Proxy){' (proxy)'})" -ForegroundColor Green

          # Save to .git-credentials for next time
          $credLine = "https://$($me.login):${Token}@github.com"
          $credFile = "$env:USERPROFILE\.git-credentials"
          $lines = @()
          if (Test-Path $credFile) { $lines = Get-Content $credFile -ErrorAction SilentlyContinue }
          $lines = $lines | Where-Object { $_ -notmatch 'github\.com' }
          $lines += $credLine
          Set-Content -Path $credFile -Value $lines -Force
          Write-Host "[dao] token saved to .git-credentials" -ForegroundColor DarkGray
          break
        }
        if ($poll.error -eq "authorization_pending") { continue }
        if ($poll.error -eq "slow_down") { Start-Sleep 5; continue }
        if ($poll.error -eq "expired_token") {
          Write-Host "[dao] code expired, retry" -ForegroundColor Red; exit 1
        }
      } catch {}
    }
  }
}

if (-not $Token) { Write-Host "[dao] no token" -ForegroundColor Red; exit 1 }

$API = "https://api.github.com/repos/$Repo"

# ── Ensure label ──
try { dao-api "$API/labels/$LABEL" | Out-Null }
catch { try { dao-api "$API/labels" Post (@{name=$LABEL;color="0075ca"}|ConvertTo-Json) | Out-Null } catch {} }

# ── Transport loop ──
Write-Host "[dao] transport active (Ctrl+C stop)" -ForegroundColor Cyan
$seen = @{}

while ($true) {
  try {
    $issues = dao-api "$API/issues?state=open&per_page=20" |
              Where-Object { $_.labels.name -contains $LABEL }
    foreach ($i in $issues) {
      if ($seen[$i.number]) { continue }
      $seen[$i.number] = 1
      $cmd = $i.body
      if (-not $cmd) { continue }
      Write-Host "[dao] #$($i.number) > $cmd" -ForegroundColor Yellow
      $sw = [Diagnostics.Stopwatch]::StartNew()
      try { $out = cmd /c $cmd 2>&1 | Out-String; $ok = $true }
      catch { $out = $_.Exception.Message; $ok = $false }
      $sw.Stop()
      if ($out.Length -gt 60000) { $out = $out.Substring(0,60000) + "`n[truncated]" }
      $res = "**Result** ($($sw.ElapsedMilliseconds)ms) ``$ok```n`````n$out``````n"
      try { dao-api "$API/issues/$($i.number)/comments" Post (@{body=$res}|ConvertTo-Json) | Out-Null } catch {}
      try { dao-api "$API/issues/$($i.number)" Patch (@{state="closed"}|ConvertTo-Json) | Out-Null } catch {}
      Write-Host "[dao] #$($i.number) < done ($($sw.ElapsedMilliseconds)ms)" -ForegroundColor Green
    }
  } catch {}
  Start-Sleep 5
}
