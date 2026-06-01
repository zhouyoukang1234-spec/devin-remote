<#
dao agent — transparent transport pipe receiver
GitHub Issues = invisible command channel
Usage: irm https://raw.githubusercontent.com/{user}/devin-remote/main/agent.ps1 | iex
#>
param([string]$Repo = "zhouyoukang1234-spec/devin-remote", [string]$Token = "", [string]$Secret = $env:DAO_SECRET)
$LABEL = "devin-cmd"

# ── Single Add-Type: WinCred + HttpClient + auto-proxy ──
Add-Type -ReferencedAssemblies System.Net.Http -TypeDefinition @"
using System; using System.Runtime.InteropServices; using System.Net.Http; using System.Text;

public class DaoCred {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    struct CRED { public uint Flags; public uint Type; public string TargetName; public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public uint CredentialBlobSize; public IntPtr CredentialBlob;
        public uint Persist; public uint AttributeCount; public IntPtr Attributes;
        public string TargetAlias; public string UserName; }
    [DllImport("Advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    static extern bool CredRead(string t, uint ty, uint f, out IntPtr c);
    [DllImport("Advapi32.dll")] static extern void CredFree(IntPtr b);
    public static string Get(string t) {
        IntPtr cp; if(!CredRead(t,1,0,out cp)) return "";
        try { var cr=Marshal.PtrToStructure<CRED>(cp);
            if(cr.CredentialBlobSize>0&&cr.CredentialBlob!=IntPtr.Zero){
                byte[] b=new byte[cr.CredentialBlobSize]; Marshal.Copy(cr.CredentialBlob,b,0,(int)cr.CredentialBlobSize);
                return Encoding.Unicode.GetString(b); } return "";
        } finally { CredFree(cp); } }
}

public class DaoHttp {
    static string _proxy = "";
    public static void SetProxy(string p) { _proxy = p; }
    static HttpClient Make() {
        var h = new HttpClientHandler();
        if(!string.IsNullOrEmpty(_proxy)) h.Proxy = new System.Net.WebProxy(_proxy);
        var c = new HttpClient(h);
        c.DefaultRequestHeaders.Add("User-Agent","dao/1");
        c.DefaultRequestHeaders.Add("Accept","application/json");
        return c; }
    static HttpClient MakeAuth(string token) {
        var c = Make(); c.DefaultRequestHeaders.Add("Authorization","Bearer "+token);
        c.DefaultRequestHeaders.Add("Accept","application/vnd.github+json"); return c; }
    public static string Get(string url, string token) {
        return MakeAuth(token).GetAsync(url).Result.Content.ReadAsStringAsync().Result; }
    public static string Post(string url, string json, string token) {
        var c = MakeAuth(token);
        return c.PostAsync(url, new StringContent(json, Encoding.UTF8, "application/json")).Result.Content.ReadAsStringAsync().Result; }
    public static string Patch(string url, string json, string token) {
        var c = MakeAuth(token);
        var r = new HttpRequestMessage(new HttpMethod("PATCH"), url) { Content = new StringContent(json, Encoding.UTF8, "application/json") };
        return c.SendAsync(r).Result.Content.ReadAsStringAsync().Result; }
    public static string PostNoAuth(string url, string json) {
        return Make().PostAsync(url, new StringContent(json, Encoding.UTF8, "application/json")).Result.Content.ReadAsStringAsync().Result; }
}
"@

# ── Auto proxy detection ──
$proxyUrl = ""
$proxyEnv = $env:HTTPS_PROXY, $env:HTTP_PROXY | Where-Object { $_ } | Select-Object -First 1
if ($proxyEnv) { $proxyUrl = $proxyEnv -replace '^https?://', 'http://' }
else {
  foreach ($port in 7897, 7890, 10808, 1080, 2080) {
    try { $c = New-Object Net.Sockets.TcpClient("127.0.0.1", $port)
          if ($c.Connected) { $proxyUrl = "http://127.0.0.1:$port"; $c.Close(); break } } catch {}
  }
}
[DaoHttp]::SetProxy($proxyUrl)

# ── Auto auth chain (zero user input) ──
if (-not $Token) {
  # 1. Windows Credential Manager (what git actually uses — most reliable)
  $t1 = [DaoCred]::Get("git:https://github.com")
  $t2 = [DaoCred]::Get("git:https://zhouyoukang@github.com")
  if ($t1) { $Token = $t1 } elseif ($t2) { $Token = $t2 }
  # 2. gh CLI
  if (-not $Token) { try { $t = & gh auth token 2>$null; if ($t -and $t -notmatch 'error') { $Token = $t.Trim() } } catch {} }
  # 3. Env vars
  if (-not $Token) { $Token = $env:DAO_TOKEN; if (-not $Token) { $Token = $env:GITHUB_TOKEN } }
  # 4. .git-credentials
  if (-not $Token -and (Test-Path "$env:USERPROFILE\.git-credentials")) {
    $gc = Get-Content "$env:USERPROFILE\.git-credentials" -EA 0 | Where-Object { $_ -match 'github\.com' } | Select-Object -First 1
    if ($gc -match ':([^:@]+)@github') { $Token = $Matches[1] }
  }
  # 5. Device Flow (last resort — uses GitHub CLI's public OAuth App)
  if (-not $Token) {
    $CID = "178c6fc778ccc68e1d6a"
    try {
      $dfJson = [DaoHttp]::PostNoAuth("https://github.com/login/device/code", '{"client_id":"' + $CID + '","scope":"repo"}')
      if ($dfJson -match '"user_code":"([^"]+)"') { $uc = $Matches[1] }
      if ($dfJson -match '"device_code":"([^"]+)"') { $dc = $Matches[1] }
      if ($dfJson -match '"interval":(\d+)') { $iv = [int]$Matches[1] }
      if ($dfJson -match '"expires_in":(\d+)') { $exp = [int]$Matches[1] }
      if ($uc) {
        Write-Host "`n  Open: https://github.com/login/device" -F White -B DarkBlue
        Write-Host "  Code: $uc`n" -F Yellow
        Write-Host "  Waiting for authorization..." -F Gray
        $end = (Get-Date).AddSeconds($exp)
        while ((Get-Date) -lt $end) {
          Start-Sleep $iv
          $pJson = [DaoHttp]::PostNoAuth("https://github.com/login/oauth/access_token", '{"client_id":"' + $CID + '","device_code":"' + $dc + '"}')
          if ($pJson -match '"access_token":"([^"]+)"') { $Token = $Matches[1]; break }
          if ($pJson -match '"error":"expired_token"') { break }
        }
        if ($Token) {
          $meJson = [DaoHttp]::Get("https://api.github.com/user", $Token)
          if ($meJson -match '"login":"([^"]+)"') { $login = $Matches[1] }
          $cf = "$env:USERPROFILE\.git-credentials"
          $lines = if (Test-Path $cf) { Get-Content $cf -EA 0 | Where-Object { $_ -notmatch 'github' } } else { @() }
          $lines += "https://${login}:${Token}@github.com"
          Set-Content $cf $lines -Force
          Write-Host "[dao] Device Flow: $login authenticated" -F Green
        }
      }
    } catch { Write-Host "[dao] Device Flow failed: $_" -F Red }
  }
}
if (-not $Token) { Write-Host "[dao] no token — set DAO_TOKEN env or run: gh auth login" -F Red; exit 1 }

# ── Verify token ──
$meJson = [DaoHttp]::Get("https://api.github.com/user", $Token)
if ($meJson -match '"login":"([^"]+)"') { Write-Host "[dao] $($Matches[1]) @ $Repo$(if($proxyUrl){' (proxy)'})" -F Green }
else { Write-Host "[dao] auth failed" -F Red; exit 1 }

$API = "https://api.github.com/repos/$Repo"

# ── Protocol helpers (pure PS — HMAC/base64 cross-platform) ──
function ConvertTo-DaoB64([string]$s) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s)) }
function ConvertFrom-DaoB64([string]$s) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s)) }
function Get-DaoHmac([string]$key, [string]$msg) {
  $h = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($key))
  try { (($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($msg)) | ForEach-Object { $_.ToString('x2') }) -join '') }
  finally { $h.Dispose() }
}
# Constant-time compare. Empty $Secret = signing disabled (zero-config default).
function Test-DaoSig([string]$key, [string]$b64, [string]$sig) {
  if (-not $key) { return $true }
  if (-not $sig -or $sig -eq '-') { return $false }
  $calc = Get-DaoHmac $key $b64
  if ($calc.Length -ne $sig.Length) { return $false }
  $diff = 0
  for ($k = 0; $k -lt $calc.Length; $k++) { $diff = $diff -bor ([byte][char]$calc[$k] -bxor [byte][char]$sig[$k]) }
  return ($diff -eq 0)
}
# Result protocol: line1 marker+status+ms, line2 base64(output). No markdown fences.
function Send-DaoResult([int]$num, [string]$status, [long]$ms, [string]$output) {
  if ($output.Length -gt 60000) { $output = $output.Substring(0, 60000) + "`n[truncated]" }
  $body = "dao1-result $status $ms`n" + (ConvertTo-DaoB64 $output)
  $json = '{"body":' + ($body | ConvertTo-Json) + '}'
  try { [DaoHttp]::Post("$API/issues/$num/comments", $json, $Token) | Out-Null } catch {}
  try { [DaoHttp]::Patch("$API/issues/$num", '{"state":"closed"}', $Token) | Out-Null } catch {}
}

# ── Ensure label ──
try { [DaoHttp]::Get("$API/labels/$LABEL", $Token) | Out-Null }
catch { try { [DaoHttp]::Post("$API/labels", '{"name":"' + $LABEL + '","color":"0075ca"}', $Token) | Out-Null } catch {} }

# ── Transport loop ──
$boot = [DateTimeOffset]::UtcNow.AddSeconds(-5)
$signed = [bool]$Secret
if (-not $signed) { Write-Host "[dao] WARNING: unsigned mode — set DAO_SECRET on both ends to require HMAC" -F Yellow }
Write-Host "[dao] pipe active (signed=$signed) (Ctrl+C stop)" -F Cyan
$seen = @{}
while ($true) {
  try {
    $issuesJson = [DaoHttp]::Get("$API/issues?labels=$LABEL&state=open&per_page=20&sort=created&direction=asc", $Token)
    $issues = $issuesJson | ConvertFrom-Json
    foreach ($i in $issues) {
      $id = $i.number
      if ($seen[$id]) { continue }
      $seen[$id] = 1
      if ($seen.Count -gt 500) { $seen = @{}; $seen[$id] = 1 }

      # Skip backlog created before this agent booted (no mass-execution on reconnect)
      $created = [DateTimeOffset]::Parse($i.created_at)
      if ($created -lt $boot) {
        Write-Host "[dao] ~ skip stale #$id" -F DarkGray
        Send-DaoResult $id "False" 0 "[dao] skipped: stale command (agent (re)started)"
        continue
      }

      # Idempotency: if already answered, just ensure closed (kills duplicate execution)
      $cmts = [DaoHttp]::Get("$API/issues/$id/comments", $Token) | ConvertFrom-Json
      if ($cmts | Where-Object { $_.body -like 'dao1-result*' }) {
        try { [DaoHttp]::Patch("$API/issues/$id", '{"state":"closed"}', $Token) | Out-Null } catch {}
        continue
      }

      # Parse signed envelope: "dao1 <b64cmd> <hmac|->"
      $raw = if ($i.body) { ($i.body -replace '\r', '').Trim() } else { '' }
      $parts = $raw -split '\s+'
      if ($parts.Count -lt 2 -or $parts[0] -ne 'dao1') {
        Write-Host "[dao] ! bad envelope #$id" -F Red
        Send-DaoResult $id "False" 0 "[dao] rejected: bad envelope (expected 'dao1 <b64> <sig>')"
        continue
      }
      $b64 = $parts[1]
      $sig = if ($parts.Count -ge 3) { $parts[2] } else { '-' }
      if (-not (Test-DaoSig $Secret $b64 $sig)) {
        Write-Host "[dao] ! signature rejected #$id" -F Red
        Send-DaoResult $id "False" 0 "[dao] rejected: invalid/missing signature"
        continue
      }
      try { $cmd = ConvertFrom-DaoB64 $b64 } catch {
        Send-DaoResult $id "False" 0 "[dao] rejected: bad base64 payload"
        continue
      }

      Write-Host "[dao] > $cmd" -F Yellow
      $sw = [Diagnostics.Stopwatch]::StartNew()
      try { $out = Invoke-Expression $cmd 2>&1 | Out-String; $ok = "True" } catch { $out = $_.Exception.Message; $ok = "False" }
      $sw.Stop()
      Send-DaoResult $id $ok $sw.ElapsedMilliseconds $out
      Write-Host "[dao] < #$id done ($($sw.ElapsedMilliseconds)ms)" -F Green
    }
  } catch {}
  Start-Sleep 5
}
