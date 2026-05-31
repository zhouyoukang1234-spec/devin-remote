<#
dao agent — transparent transport pipe receiver
GitHub Issues = invisible command channel
Usage: irm https://raw.githubusercontent.com/{user}/devin-remote/main/agent.ps1 | iex
#>
param([string]$Repo = "zhouyoukang1234-spec/devin-remote", [string]$Token = "")
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
if ($proxyEnv) { $proxyUrl = $proxyUrl -replace '^https?://', 'http://' }
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

# ── Ensure label ──
try { [DaoHttp]::Get("$API/labels/$LABEL", $Token) | Out-Null }
catch { try { [DaoHttp]::Post("$API/labels", '{"name":"' + $LABEL + '","color":"0075ca"}', $Token) | Out-Null } catch {} }

# ── Transport loop ──
Write-Host "[dao] pipe active (Ctrl+C stop)" -F Cyan
$seen = @{}
while ($true) {
  try {
    $issuesJson = [DaoHttp]::Get("$API/issues?labels=$LABEL&state=open&per_page=10", $Token)
    $issues = $issuesJson | ConvertFrom-Json
    foreach ($i in $issues) {
      $id = $i.number
      if ($seen[$id]) { continue }
      $seen[$id] = 1
      $cmd = $i.body
      if (-not $cmd) { continue }
      Write-Host "[dao] > $cmd" -F Yellow
      $sw = [Diagnostics.Stopwatch]::StartNew()
      try { $out = Invoke-Expression $cmd 2>&1 | Out-String; $ok = $true } catch { $out = $_.Exception.Message; $ok = $false }
      $sw.Stop()
      if ($out.Length -gt 60000) { $out = $out.Substring(0, 60000) + "`n[truncated]" }
      $res = "**Result** ($($sw.ElapsedMilliseconds)ms) ``$ok```n`````n$out``````n"
      $resJson = '{"body":' + ($res | ConvertTo-Json) + '}'
      try { [DaoHttp]::Post("$API/issues/$($i.number)/comments", $resJson, $Token) | Out-Null } catch {}
      try { [DaoHttp]::Patch("$API/issues/$($i.number)", '{"state":"closed"}', $Token) | Out-Null } catch {}
      Write-Host "[dao] < done ($($sw.ElapsedMilliseconds)ms)" -F Green
    }
  } catch {}
  Start-Sleep 5
}
