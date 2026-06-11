"""Robust DAO exec: command sent via -EncodedCommand (ASCII), output returned base64 (ASCII).
Avoids the relay's lossy Chinese-codepage corruption in BOTH directions."""
import sys, base64
sys.path.insert(0, r"C:\Users\Administrator")
from dao_sdk import dao

def rexec(body, agent="179", timeout=30):
    """body: PowerShell that assigns final text to $out. Returns decoded UTF-8 string."""
    script = (
        "$ErrorActionPreference='SilentlyContinue'\n"
        "$out=''\n"
        + body + "\n"
        "[Console]::Out.Write([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$out)))"
    )
    b64cmd = base64.b64encode(script.encode("utf-16-le")).decode()
    raw = dao(f"powershell -NoProfile -EncodedCommand {b64cmd}", agent, timeout=timeout)
    if raw.startswith("[") and ("unreachable" in raw or "no-stdout" in raw or "stderr" in raw):
        return f"<<ERR>> {raw}"
    try:
        return base64.b64decode(raw.strip()).decode("utf-8", "replace")
    except Exception as e:
        return f"<<DECODE-ERR {e}>> raw={raw[:200]!r}"

def ls(path, agent="179", timeout=25, recurse=False, depth=0):
    if recurse:
        body = f"$p='{path}'; if(Test-Path -LiteralPath $p){{ $out=(Get-ChildItem -LiteralPath $p -Recurse -Depth {depth} -Force | Select-Object -ExpandProperty FullName) -join \"`n\" }} else {{ $out='NO:'+$p }}"
    else:
        body = f"$p='{path}'; if(Test-Path -LiteralPath $p){{ $out=(Get-ChildItem -LiteralPath $p -Force | ForEach-Object {{ ($(if($_.PSIsContainer){{'D'}}else{{'F'}}))+' '+$_.Name }}) -join \"`n\" }} else {{ $out='NO:'+$p }}"
    return rexec(body, agent, timeout)

if __name__ == "__main__":
    print("sanity:", rexec("$out='ok '+(hostname)", "179", 20))
    for p in [
        "V:\\道",
        "V:\\道\\道生一\\一生二\\Windsurf万法归宗\\070-插件_Plugins",
        "V:\\道\\道生一\\一生二\\Windsurf万法归宗\\070-插件_Plugins\\010-WAM本源_Origin",
    ]:
        print(f"\n## {p}")
        print(ls(p))
