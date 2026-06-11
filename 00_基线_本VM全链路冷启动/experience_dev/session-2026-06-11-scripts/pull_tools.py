import os, sys, io
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import dao_sdk as d

BASE = "E:\\DAO_ARCHIVE\\00_基线_本VM全链路冷启动"
OUT = r"C:\Users\Administrator\dao\archive_mirror\00_tools"
os.makedirs(OUT, exist_ok=True)

files = [
    r"06_bootstrap.ps1",
    r"03_本对话成果与突破.md",
    r"04_交接_下一个Agent.md",
    r"05_补充_e0405e88成果整合.md",
    r"tools\dao_b64.py",
    r"tools\dao_put.py",
    r"tools\dao_sdk.py",
    r"tools\dl_repo.py",
    r"tools\verify_channel.py",
    r"artifacts\devin_user_settings.json",
]
for rel in files:
    rp = BASE + "\\" + rel
    try:
        b = d.fread_bytes(rp, "141")
        lp = os.path.join(OUT, rel.replace("\\","__"))
        with open(lp, "wb") as f:
            f.write(b)
        print(f"OK {len(b):>7} {rel}")
    except Exception as ex:
        print(f"ERR {rel}: {ex}")
