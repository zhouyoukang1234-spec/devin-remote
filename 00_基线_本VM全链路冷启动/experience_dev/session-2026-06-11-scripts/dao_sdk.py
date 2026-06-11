import urllib.request, json, ssl, time, os, sys

# === proxy immunity + SSL skip (trycloudflare self-signed) ===
for k in ('HTTP_PROXY', 'HTTPS_PROXY', 'http_proxy', 'https_proxy'):
    os.environ.pop(k, None)
os.environ['NO_PROXY'] = '*'

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

opener = urllib.request.build_opener(
    urllib.request.ProxyHandler({}),
    urllib.request.HTTPSHandler(context=ctx),
)
urllib.request.install_opener(opener)

URL   = os.environ.get("DAO_URL", "https://qualify-wrap-ministries-liable.trycloudflare.com")
TOKEN = os.environ.get("DAO_TOKEN", "dao-ps-agent-2026")

def api(method, path, body=None, timeout=30):
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(f"{URL}{path}", data=data,
        headers={"Authorization": f"Bearer {TOKEN}",
                 "Content-Type": "application/json"},
        method=method)
    try:
        return json.loads(urllib.request.urlopen(req, timeout=timeout).read())
    except urllib.error.HTTPError as e:
        return json.loads(e.read()) if e.fp else {"error": str(e)}
    except Exception as e:
        return {"error": str(e)}

def health():
    return api("GET", "/api/health")

def agents():
    return api("GET", "/api/agents")

def dao(cmd, agent="ZHOUMAC", timeout=30, retries=3):
    for i in range(retries):
        r = api("POST", "/api/exec-sync", {
            "agent_id": agent, "cmd": cmd, "timeout": timeout
        }, timeout=timeout + 15)
        if r.get("status") == "completed":
            return r["result"]["stdout"]
        if "not found" in str(r.get("error", "")):
            time.sleep(5)
    return f"[dao] unreachable: {agent} :: {r}"

def dao_raw(cmd, agent="ZHOUMAC", timeout=30):
    r = api("POST", "/api/exec-sync", {
        "agent_id": agent, "cmd": cmd, "timeout": timeout
    }, timeout=timeout + 15)
    return r.get("result", {}) if r.get("status") == "completed" else r

import base64

def typed(agent, typ, payload, timeout=60):
    r = api("POST", "/api/exec-sync", {
        "agent_id": agent, "type": typ, "payload": payload, "timeout": timeout
    }, timeout=timeout + 15)
    return r

def fread(path, agent="ZHOUMAC", timeout=60, encoding="utf-8"):
    """Read a remote file, return decoded text."""
    r = typed(agent, "file_read", {"path": path}, timeout)
    res = r.get("result", r)
    b64 = res.get("content_base64") or res.get("content") or res.get("data")
    if not b64:
        return f"[fread err] {json.dumps(r, ensure_ascii=False)[:500]}"
    raw = base64.b64decode(b64)
    for enc in (encoding, "utf-8", "gbk", "latin-1"):
        try:
            return raw.decode(enc)
        except Exception:
            continue
    return raw.decode("utf-8", "replace")

def fread_bytes(path, agent="ZHOUMAC", timeout=120):
    """Read a remote file, return raw bytes (binary-safe)."""
    r = typed(agent, "file_read", {"path": path}, timeout)
    res = r.get("result", r)
    b64 = res.get("content_base64") or res.get("content") or res.get("data")
    if not b64:
        raise RuntimeError(f"[fread_bytes err] {json.dumps(r, ensure_ascii=False)[:500]}")
    return base64.b64decode(b64)

def fwrite(path, content, agent="ZHOUMAC", timeout=60):
    b64 = base64.b64encode(content.encode("utf-8")).decode()
    r = typed(agent, "file_write", {"path": path, "content_base64": b64}, timeout)
    return r

def ps(cmd, agent="ZHOUMAC", timeout=60, retries=3):
    """Run a PowerShell command with UTF-8 output (no codepage mojibake)."""
    wrapped = (
        "powershell -NoProfile -Command \""
        "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; "
        "$OutputEncoding=[System.Text.Encoding]::UTF8; "
        + cmd.replace('"', '`"') +
        "\""
    )
    return dao(wrapped, agent, timeout, retries)

if __name__ == "__main__":
    print("URL:", URL)
    print("health:", json.dumps(health(), ensure_ascii=False))
    print("agents:", json.dumps(agents(), ensure_ascii=False))
