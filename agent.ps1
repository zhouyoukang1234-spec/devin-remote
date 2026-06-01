<#
dao agent - the user PC end of a transparent command pipe.

GitHub is just the wire: a data-only branch (default: dao-pipe) carries the traffic.
The sender writes cmd/<id> (base64 of a command); this agent runs it and writes
res/<id> (exit code + base64 of the output). Plain git only - no GitHub API token,
no PAT; it reuses the machine's own git access to the repo.

  irm https://raw.githubusercontent.com/zhouyoukang1234-spec/devin-remote/main/agent.ps1 | iex

Clock-free: at startup the agent remembers which commands already exist and ignores
them; it then runs only commands that appear afterwards. No timestamps, so two
machines' clocks can never disagree.
#>
param(
  [string]$Repo   = $(if ($env:DAO_REPO)   { $env:DAO_REPO }   else { "zhouyoukang1234-spec/devin-remote" }),
  [string]$Pipe   = $(if ($env:DAO_PIPE)   { $env:DAO_PIPE }   else { "dao-pipe" }),
  [string]$Remote = $(if ($env:DAO_REMOTE) { $env:DAO_REMOTE } else { "" }),
  [string]$Cache  = $(if ($env:DAO_CACHE)  { $env:DAO_CACHE }  else { "$env:USERPROFILE\.dao-pipe" }),
  [int]   $Poll   = $(if ($env:DAO_POLL)   { [int]$env:DAO_POLL } else { 3 })
)

try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}
if (-not $Remote) { $Remote = "https://github.com/$Repo.git" }
$git = (Get-Command git -EA 0).Source
if (-not $git) { Write-Host "[dao] git not found on PATH - install Git for Windows" -F Red; exit 1 }
$work = Join-Path $Cache ($Repo -replace '[/:]', '_')

# git wrapper: pin identity + LF so the pipe is byte-stable; return ONLY the exit code
# (git's own output is captured, never leaked to the pipeline).
function Invoke-Git { param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
  $script:DaoGitOut = & $git -C $work -c user.name=dao -c user.email=dao@pipe -c core.autocrlf=false @Args 2>&1
  return $LASTEXITCODE
}
function To-B64([string]$s)   { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s)) }
function From-B64([string]$s) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s)) }

# write res/<id> = "<exit>\n<base64(output)>", commit, push (rebasing past concurrent pushes)
function Write-Result([string]$id, [int]$code, [string]$output) {
  if ($output.Length -gt 60000) { $output = $output.Substring(0, 60000) + "`n[truncated]" }
  $body = "$code`n" + (To-B64 $output) + "`n"
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

# local working clone of just the pipe branch
if (-not (Test-Path (Join-Path $work ".git"))) {
  New-Item -ItemType Directory -Force -Path $work | Out-Null
  Invoke-Git init -q | Out-Null
  Invoke-Git remote add origin $Remote | Out-Null
}
Invoke-Git remote set-url origin $Remote | Out-Null

# baseline (clock-free): snapshot the commands that already exist right now, and ignore them.
$baseline = @{}
if ((Invoke-Git fetch -q origin $Pipe) -eq 0) {
  Invoke-Git reset -q --hard "origin/$Pipe" | Out-Null
  $cmdDir = Join-Path $work "cmd"
  if (Test-Path $cmdDir) { foreach ($f in Get-ChildItem $cmdDir -File) { $baseline[$f.Name] = 1 } }
}
Write-Host "[dao] pipe active: $Repo @ $Pipe  (Ctrl+C to stop)" -F Cyan

$seen = @{}
while ($true) {
  try {
    if ((Invoke-Git fetch -q origin $Pipe) -ne 0) { Start-Sleep $Poll; continue }  # branch may not exist yet
    Invoke-Git reset -q --hard "origin/$Pipe" | Out-Null
    $cmdDir = Join-Path $work "cmd"
    if (Test-Path $cmdDir) {
      foreach ($f in Get-ChildItem $cmdDir -File | Sort-Object Name) {
        $id = $f.Name
        if ($baseline[$id] -or $seen[$id]) { continue }                                  # pre-existing or done this run
        if (Test-Path (Join-Path $work "res/$id")) { $seen[$id] = 1; continue }           # already answered (idempotent)
        $seen[$id] = 1

        $b64 = ((Get-Content $f.FullName -Raw) -replace '\s', '')
        try { $cmd = From-B64 $b64 } catch { Write-Result $id 1 "[dao] bad base64 payload" | Out-Null; continue }

        Write-Host "[dao] > $cmd" -F Yellow
        $errBefore = $Error.Count; $global:LASTEXITCODE = 0
        try {
          $raw = Invoke-Expression $cmd 2>&1
          $out = ($raw | Out-String)
          # failure if the command raised an error or a native exe returned non-zero
          $code = if (($Error.Count -gt $errBefore) -or ($LASTEXITCODE -ne 0)) { 1 } else { 0 }
        } catch { $out = $_.Exception.Message; $code = 1 }
        if (Write-Result $id $code $out) { Write-Host "[dao] < $id done" -F Green }
        else { Write-Host "[dao] ! push failed for $id" -F Red }
      }
    }
  } catch {}
  Start-Sleep $Poll
}
