<#
dao agent (git transport) - transparent transport pipe receiver
A data-only orphan branch (default: dao-pipe) is the channel: the sender writes
cmd/<id>, this agent executes it and writes res/<id>. Uses ONLY local git, so the
user needs no GitHub API token - just git access to their own fork.
Usage: irm https://raw.githubusercontent.com/{user}/devin-remote/main/agent-git.ps1 | iex
#>
param(
  [string]$Repo   = "zhouyoukang1234-spec/devin-remote",
  [string]$Secret = $env:DAO_SECRET,
  [string]$Pipe   = $(if ($env:DAO_PIPE) { $env:DAO_PIPE } else { "dao-pipe" }),
  [string]$Remote = $(if ($env:DAO_REMOTE) { $env:DAO_REMOTE } else { "" }),
  [string]$Cache  = $(if ($env:DAO_CACHE) { $env:DAO_CACHE } else { "$env:USERPROFILE\.dao-pipe" })
)

# Emit nothing non-ASCII to the OEM console unrendered; force UTF-8 so logs are clean.
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}
if (-not $Remote) { $Remote = "https://github.com/$Repo.git" }
$git = (Get-Command git -EA 0).Source
if (-not $git) { Write-Host "[dao] git not found on PATH - install Git for Windows" -F Red; exit 1 }
$work = Join-Path $Cache ($Repo -replace '[/:]', '_')

# -- git helper: pin identity + LF so the pipe is byte-stable; return ONLY the exit code
# (git's own stdout/stderr is captured into $script:DaoGitOut, never leaked to the pipeline).
function Invoke-Git { param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
  $script:DaoGitOut = & $git -C $work -c user.name=dao -c user.email=dao@pipe -c core.autocrlf=false @Args 2>&1
  return $LASTEXITCODE
}

# -- Protocol helpers (pure PS - HMAC/base64 cross-platform) --
function ConvertTo-DaoB64([string]$s) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s)) }
function ConvertFrom-DaoB64([string]$s) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s)) }
function Get-DaoHmac([string]$key, [string]$msg) {
  $h = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($key))
  try { (($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($msg)) | ForEach-Object { $_.ToString('x2') }) -join '') }
  finally { $h.Dispose() }
}
function Test-DaoSig([string]$key, [string]$b64, [string]$sig) {
  if (-not $key) { return $true }
  if (-not $sig -or $sig -eq '-') { return $false }
  $calc = Get-DaoHmac $key $b64
  if ($calc.Length -ne $sig.Length) { return $false }
  $diff = 0
  for ($k = 0; $k -lt $calc.Length; $k++) { $diff = $diff -bor ([byte][char]$calc[$k] -bxor [byte][char]$sig[$k]) }
  return ($diff -eq 0)
}

# -- Write res/<id> as UTF-8 (no BOM), commit, push (rebasing onto concurrent pushes) --
function Write-DaoResult([string]$id, [string]$status, [long]$ms, [string]$output) {
  if ($output.Length -gt 60000) { $output = $output.Substring(0, 60000) + "`n[truncated]" }
  $body = "dao1-result $status $ms`n" + (ConvertTo-DaoB64 $output) + "`n"
  $resDir = Join-Path $work "res"
  if (-not (Test-Path $resDir)) { New-Item -ItemType Directory -Force -Path $resDir | Out-Null }
  [IO.File]::WriteAllText((Join-Path $resDir $id), $body, (New-Object System.Text.UTF8Encoding $false))
  Invoke-Git add "res/$id" | Out-Null
  Invoke-Git commit -q -m "dao: res $id" | Out-Null
  for ($i = 0; $i -lt 6; $i++) {
    if ((Invoke-Git push -q origin "HEAD:$Pipe") -eq 0) { return $true }
    if ((Invoke-Git fetch -q origin $Pipe) -ne 0) { return $false }
    if ((Invoke-Git rebase -q "origin/$Pipe") -ne 0) { Invoke-Git rebase --abort | Out-Null; return $false }
  }
  return $false
}

# -- Local working clone of just the pipe branch --
if (-not (Test-Path (Join-Path $work ".git"))) {
  New-Item -ItemType Directory -Force -Path $work | Out-Null
  Invoke-Git init -q | Out-Null
  Invoke-Git remote add origin $Remote | Out-Null
}
Invoke-Git remote set-url origin $Remote | Out-Null

$signed = [bool]$Secret
if (-not $signed) { Write-Host "[dao] WARNING: unsigned mode - set DAO_SECRET on both ends to require HMAC" -F Yellow }
Write-Host "[dao] git pipe active: $Repo @ $Pipe (signed=$signed) (Ctrl+C stop)" -F Cyan

$bootMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - 5000
$seen = @{}
while ($true) {
  try {
    if ((Invoke-Git fetch -q origin $Pipe) -ne 0) { Start-Sleep 5; continue }  # branch may not exist yet
    Invoke-Git reset -q --hard "origin/$Pipe" | Out-Null
    $cmdDir = Join-Path $work "cmd"
    if (Test-Path $cmdDir) {
      foreach ($f in Get-ChildItem $cmdDir -File | Sort-Object Name) {
        $id = $f.Name
        if ($seen[$id]) { continue }
        if (Test-Path (Join-Path $work "res/$id")) { $seen[$id] = 1; continue }  # already answered (idempotent)
        $ms = 0L; [void][int64]::TryParse(($id -split '-')[0], [ref]$ms)
        if ($ms -lt $bootMs) { $seen[$id] = 1; Write-Host "[dao] ~ skip stale $id" -F DarkGray; continue }
        $seen[$id] = 1

        $raw = (Get-Content $f.FullName -Raw) -replace '\r', ''
        $parts = $raw.Trim() -split '\s+'
        if ($parts.Count -lt 2 -or $parts[0] -ne 'dao1') {
          Write-DaoResult $id "False" 0 "[dao] rejected: bad envelope (expected 'dao1 <b64> <sig>')" | Out-Null; continue
        }
        $b64 = $parts[1]; $sig = if ($parts.Count -ge 3) { $parts[2] } else { '-' }
        if (-not (Test-DaoSig $Secret $b64 $sig)) {
          Write-Host "[dao] ! signature rejected $id" -F Red
          Write-DaoResult $id "False" 0 "[dao] rejected: invalid/missing signature" | Out-Null; continue
        }
        try { $cmd = ConvertFrom-DaoB64 $b64 } catch { Write-DaoResult $id "False" 0 "[dao] rejected: bad base64 payload" | Out-Null; continue }

        Write-Host "[dao] > $cmd" -F Yellow
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try { $out = Invoke-Expression $cmd 2>&1 | Out-String; $ok = "True" } catch { $out = $_.Exception.Message; $ok = "False" }
        $sw.Stop()
        if (Write-DaoResult $id $ok $sw.ElapsedMilliseconds $out) {
          Write-Host "[dao] < $id done ($($sw.ElapsedMilliseconds)ms)" -F Green
        } else {
          Write-Host "[dao] ! push failed for $id (will not retry)" -F Red
        }
      }
    }
  } catch {}
  Start-Sleep 5
}
