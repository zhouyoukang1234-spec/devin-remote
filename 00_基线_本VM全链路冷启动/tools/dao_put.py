"""Robust push to 141 (DESKTOP-MASTER) via relay, base64 for BOTH path and content.
Avoids the relay's lossy CJK corruption entirely (everything in transit is ASCII).
- put_text(remote_path, text): single-shot UTF-8 text write
- put_file(remote_path, local_path): chunked binary upload (for VSIX etc.)
- mkdir(remote_path)
"""
import sys, base64, os
sys.path.insert(0, r"C:\Users\Administrator")
from dao_sdk import dao

A = "DESKTOP-MASTER"

def _enc(ps):
    return base64.b64encode(ps.encode("utf-16-le")).decode()

def _run(ps, agent=A, timeout=45):
    return dao(f"powershell -NoProfile -EncodedCommand {_enc(ps)}", agent, timeout)

def mkdir(remote_path, agent=A):
    pb = base64.b64encode(remote_path.encode("utf-8")).decode()
    ps = (f"$p=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{pb}'));"
          "if(-not(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Force -Path $p|Out-Null};"
          "[Console]::Out.Write('MKDIR '+$p)")
    return _run(ps, agent)

def put_text(remote_path, text, agent=A):
    return put_bytes(remote_path, text.encode("utf-8"), agent)

def put_bytes(remote_path, data, agent=A):
    pb = base64.b64encode(remote_path.encode("utf-8")).decode()
    db = base64.b64encode(data).decode()
    # b64 of content; if too large for one -EncodedCommand, chunk into a temp file
    CHUNK = 6000  # chars of base64 per relay call
    if len(db) <= CHUNK:
        ps = (f"$p=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{pb}'));"
              "$d=Split-Path -Parent $p; if(-not(Test-Path -LiteralPath $d)){New-Item -ItemType Directory -Force -Path $d|Out-Null};"
              f"[IO.File]::WriteAllBytes($p,[Convert]::FromBase64String('{db}'));"
              "[Console]::Out.Write('WROTE '+(Get-Item -LiteralPath $p).Length+' '+$p)")
        return _run(ps, agent)
    # chunked: write each chunk to <path>.b64 (append), then decode to final
    tmp_b64 = remote_path + ".b64part"
    tb = base64.b64encode(tmp_b64.encode("utf-8")).decode()
    # init: ensure dir + empty file
    init = (f"$p=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{tb}'));"
            "$d=Split-Path -Parent $p; if(-not(Test-Path -LiteralPath $d)){New-Item -ItemType Directory -Force -Path $d|Out-Null};"
            "Set-Content -LiteralPath $p -Value '' -NoNewline -Encoding ascii;[Console]::Out.Write('INIT')")
    print("  init:", _run(init, agent))
    n = (len(db) + CHUNK - 1)//CHUNK
    for i in range(n):
        part = db[i*CHUNK:(i+1)*CHUNK]
        ps = (f"$p=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{tb}'));"
              f"Add-Content -LiteralPath $p -Value '{part}' -NoNewline -Encoding ascii;"
              "[Console]::Out.Write('OK')")
        r = _run(ps, agent)
        print(f"  chunk {i+1}/{n}: {r}")
    # decode final
    fin = (f"$tp=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{tb}'));"
           f"$p=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{pb}'));"
           "$b=[Convert]::FromBase64String((Get-Content -LiteralPath $tp -Raw));"
           "[IO.File]::WriteAllBytes($p,$b);Remove-Item -LiteralPath $tp -Force;"
           "[Console]::Out.Write('FINAL '+(Get-Item -LiteralPath $p).Length+' '+$p)")
    return _run(fin, agent, timeout=60)

def put_file(remote_path, local_path, agent=A):
    with open(local_path, "rb") as f:
        data = f.read()
    return put_bytes(remote_path, data, agent)

if __name__ == "__main__":
    print(mkdir(r"E:\DAO_ARCHIVE\_put_test"))
    print(put_text(r"E:\DAO_ARCHIVE\_put_test\hello.md", "# 测试 hello 道法自然\n字符无损 round-trip OK\n"))
