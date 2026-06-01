<#
dao-exec — transparent remote command execution (Windows)
GitHub Issues = invisible transport pipe
Usage: dao-exec "command" → stdout = result (feels like local execution)
#>
param([string]$Repo = "zhouyoukang1234-spec/devin-remote", [Parameter(Mandatory)][string]$Command, [string]$Secret = $env:DAO_SECRET)
$LABEL = "devin-cmd"

# ── Add-Type: WinCred + HttpClient ──
Add-Type -ReferencedAssemblies System.Net.Http -TypeDefinition @"
using System; using System.Runtime.InteropServices; using System.Net.Http; using System.Text;

public class DaoCred2 {
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

public class DaoExec2 {
    static string _proxy = "";
    public static void SetProxy(string p) { _proxy = p; }
    static HttpClient Make(string token) {
        var h = new HttpClientHandler();
        if(!string.IsNullOrEmpty(_proxy)) h.Proxy = new System.Net.WebProxy(_proxy);
        var c = new HttpClient(h);
        c.DefaultRequestHeaders.Add("Authorization","Bearer "+token);
        c.DefaultRequestHeaders.Add("Accept","application/vnd.github+json");
        c.DefaultRequestHeaders.Add("User-Agent","dao/1"); return c; }
    public static string Post(string token, string url, string json) {
        return Make(token).PostAsync(url, new StringContent(json, Encoding.UTF8, "application/json")).Result.Content.ReadAsStringAsync().Result; }
    public static string Get(string token, string url) {
        return Make(token).GetAsync(url).Result.Content.ReadAsStringAsync().Result; }
}
"@

# ── Auto proxy ──
$proxyUrl = ""
$proxyEnv = $env:HTTPS_PROXY, $env:HTTP_PROXY | Where-Object { $_ } | Select-Object -First 1
if ($proxyEnv) { $proxyUrl = $proxyEnv -replace '^https?://', 'http://' }
else {
  foreach ($port in 7897, 7890, 10808, 1080, 2080) {
    try { $c = New-Object Net.Sockets.TcpClient("127.0.0.1", $port)
          if ($c.Connected) { $proxyUrl = "http://127.0.0.1:$port"; $c.Close(); break } } catch {}
  }
}
[DaoExec2]::SetProxy($proxyUrl)

# ── Auto token (same chain as agent.ps1) ──
$Token = ""
$t1 = [DaoCred2]::Get("git:https://github.com")
$t2 = [DaoCred2]::Get("git:https://zhouyoukang@github.com")
if ($t1) { $Token = $t1 } elseif ($t2) { $Token = $t2 }
if (-not $Token) { try { $t = & gh auth token 2>$null; if ($t -and $t -notmatch 'error') { $Token = $t.Trim() } } catch {} }
if (-not $Token) { $Token = $env:DAO_TOKEN; if (-not $Token) { $Token = $env:GITHUB_TOKEN } }
if (-not $Token -and (Test-Path "$env:USERPROFILE\.git-credentials")) {
  $gc = Get-Content "$env:USERPROFILE\.git-credentials" -EA 0 | Where-Object { $_ -match 'github\.com' } | Select-Object -First 1
  if ($gc -match ':([^:@]+)@github') { $Token = $Matches[1] }
}
if (-not $Token) { Write-Host "dao: no token — set DAO_TOKEN env" -F Red; exit 1 }

# ── Build signed envelope: "dao1 <b64cmd> <hmac|->" ──
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Command))
if ($Secret) {
  $h = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($Secret))
  try { $sig = (($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($b64)) | ForEach-Object { $_.ToString('x2') }) -join '') }
  finally { $h.Dispose() }
} else { $sig = '-' }
$body = "dao1 $b64 $sig"

# ── Send: create Issue ──
$issueJson = @{ title = "cmd"; body = $body; labels = @($LABEL) } | ConvertTo-Json -Compress
$result = [DaoExec2]::Post($Token, "https://api.github.com/repos/$Repo/issues", $issueJson)
if ($result -match '"number":(\d+)') { $num = $Matches[1] }
else { Write-Host "dao: send failed (auth ok? repo exists?)" -F Red; exit 1 }
Write-Host "[dao] #$num sent: $Command" -F DarkGray

# ── Receive: poll until closed ──
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep 3
  $issue = [DaoExec2]::Get($Token, "https://api.github.com/repos/$Repo/issues/$num")
  if ($issue -match '"state":"closed"') {
    $comments = [DaoExec2]::Get($Token, "https://api.github.com/repos/$Repo/issues/$num/comments")
    $arr = $comments | ConvertFrom-Json
    if ($arr.Count -gt 0) {
      $cbody = ($arr[$arr.Count - 1].body -replace '\r', '')
      $lines = $cbody -split "`n"
      if ($lines[0] -like 'dao1-result*') {
        $status = ($lines[0] -split '\s+')[1]
        $out = if ($lines.Count -ge 2) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($lines[1].Trim())) } else { '' }
        if ($status -eq 'False') { Write-Host $out -F Red; exit 1 }
        $out
      } else {
        # Fallback for legacy markdown-fence results
        $inBlock = $false; $output = @()
        foreach ($line in $lines) { if ($line -eq '```') { $inBlock = -not $inBlock; continue }; if ($inBlock) { $output += $line } }
        if ($output.Count -gt 0) { $output -join "`n" } else { $cbody }
      }
    }
    exit 0
  }
}
Write-Host "dao: timeout 120s — agent.ps1 running on user PC?" -F Red; exit 1
