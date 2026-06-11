import os, sys, io, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import dao_sdk as d

# Have remote write a UTF-8 tree json to disk, then read it via base64 (clean encoding)
remote_tmp = r"E:\DAO_ARCHIVE\_tree_dump.json"
cmd = (
    "$ErrorActionPreference='SilentlyContinue'; "
    "Get-ChildItem -Recurse -Depth 3 -LiteralPath 'E:\\DAO_ARCHIVE' "
    "| Select-Object FullName,@{n='Dir';e={$_.PSIsContainer}},Length "
    "| ConvertTo-Json -Depth 3 "
    "| Out-File -LiteralPath '" + remote_tmp + "' -Encoding utf8"
)
print("writing tree on remote...")
print(d.ps(cmd, "141", timeout=90)[:200])

txt = d.fread(remote_tmp, "141")
data = json.loads(txt.lstrip("\ufeff"))
OUT = r"C:\Users\Administrator\dao\archive_mirror"
os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "_tree.json"), "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=1)
print("entries:", len(data))
for e in data:
    tag = "D" if e.get("Dir") else "F"
    print(tag, e.get("Length"), e.get("FullName"))
