import os, sys, io
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import dao_sdk as d

ART = "E:\\DAO_ARCHIVE\\00_基线_本VM全链路冷启动\\artifacts"
OUT = r"C:\Users\Administrator\plugins\_artifacts_vsix"
os.makedirs(OUT, exist_ok=True)
names = [
    "dao-proxy-pro-9.9.261.vsix",
    "devin-git-auth-2.0.0.vsix",
    "rt-flow-3.16.0.vsix",
]
for n in names:
    b = d.fread_bytes(ART + "\\" + n, "141", timeout=180)
    with open(os.path.join(OUT, n), "wb") as f:
        f.write(b)
    print(f"OK {len(b):>8} {n}")
print("done")
