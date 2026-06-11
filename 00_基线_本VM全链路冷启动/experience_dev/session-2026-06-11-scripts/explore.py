import os, sys, io
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import dao_sdk as d

print("=== README.md ===")
print(d.fread("E:\\DAO_ARCHIVE\\README.md", "141"))

print("\n=== file_read test result keys ===")
r = d.typed("141", "file_read", {"path": "E:\\DAO_ARCHIVE\\README.md"})
print(list(r.keys()), list(r.get("result", {}).keys()) if isinstance(r.get("result"), dict) else r.get("result"))
