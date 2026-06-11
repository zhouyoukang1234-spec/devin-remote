import os, sys, io, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import dao_sdk as d

REMOTE_BASE = "E:\\DAO_ARCHIVE\\07_session_e0405e88\\code"
LOCAL_BASE = r"C:\Users\Administrator\plugins"

# read the tree we dumped earlier
txt = d.fread(r"E:\DAO_ARCHIVE\_tree07.json", "141")
data = json.loads(txt.lstrip("\ufeff"))

os.makedirs(LOCAL_BASE, exist_ok=True)
files = [e for e in data if not e.get("Dir")]
print(f"downloading {len(files)} files...")
ok = 0
for e in files:
    fn = e["FullName"]
    rel = fn[len(REMOTE_BASE)+1:]
    lp = os.path.join(LOCAL_BASE, rel)
    os.makedirs(os.path.dirname(lp), exist_ok=True)
    try:
        b = d.fread_bytes(fn, "141")
        with open(lp, "wb") as f:
            f.write(b)
        ok += 1
        print(f"  OK {len(b):>8}  {rel}")
    except Exception as ex:
        print(f"  ERR {rel}: {ex}")
print(f"done: {ok}/{len(files)}")
