#!/usr/bin/env python3
# 00\tools\verify_channel.py — dao-bridge 通道一键体检（VM → workers.dev relay → 141）
# 用法: python verify_channel.py
import json, urllib.request, os, sys

for k in ('HTTP_PROXY', 'HTTPS_PROXY', 'http_proxy', 'https_proxy'):
    os.environ.pop(k, None)
os.environ['NO_PROXY'] = '*'

URL = "https://dao-relay-do.zhouyoukang.workers.dev/relay/141"
TOKEN = "dao141-9c2e7a1f4b6d8035"

def call(path, body=None, timeout=40):
    # relay 信封格式: {"path","method","body"}；必须带 User-Agent 否则 CF 403
    data = json.dumps({"path": path, "method": "POST", "body": body or {}}).encode()
    req = urllib.request.Request(URL, data=data,
        headers={"Authorization": "Bearer " + TOKEN, "Content-Type": "application/json",
                 "User-Agent": "curl/8.0"}, method="POST")
    return json.loads(urllib.request.urlopen(req, timeout=timeout).read())

checks = []
try:
    r = call("/api/exec", {"cmd": "hostname", "timeout": 20})
    out = (r.get("stdout") or "").strip()
    checks.append(("exec141 hostname", len(out) > 0, out))
except Exception as e:
    checks.append(("exec141 hostname", False, str(e)))
try:
    r = call("/api/exec", {"cmd": "Test-Path E:\\DAO_ARCHIVE", "timeout": 20})
    checks.append(("E:\\DAO_ARCHIVE exists", "True" in (r.get("stdout") or ""), ""))
except Exception as e:
    checks.append(("E:\\DAO_ARCHIVE exists", False, str(e)))

ok = True
for name, passed, info in checks:
    print(("PASS " if passed else "FAIL ") + name, info if info else "")
    ok = ok and passed
print("channel check:", "ALL PASS" if ok else "FAILED - check DaoBridge141 task on 141")
sys.exit(0 if ok else 1)
