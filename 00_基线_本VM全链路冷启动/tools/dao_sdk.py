import urllib.request, json, ssl, time, os, sys

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

URL   = "https://qualify-wrap-ministries-liable.trycloudflare.com"
TOKEN = "dao-ps-agent-2026"

def api(method, path, body=None, timeout=30):
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(f"{URL}{path}", data=data,
        headers={"Authorization": f"Bearer {TOKEN}",
                 "Content-Type": "application/json"},
        method=method)
    return json.loads(urllib.request.urlopen(req, timeout=timeout).read())

def health():
    return api("GET", "/api/health")

def agents():
    return api("GET", "/api/agents")

def dao(cmd, agent="ZHOUMAC", timeout=30, retries=4):
    last = ""
    for i in range(retries):
        try:
            r = api("POST", "/api/exec-sync", {
                "agent_id": agent, "cmd": cmd, "timeout": timeout
            }, timeout=timeout + 20)
        except Exception as e:
            last = f"[dao] http err: {type(e).__name__} {e}"
            time.sleep(4)
            continue
        if r.get("status") == "completed":
            res = r.get("result", {}) or {}
            out = res.get("stdout", "")
            err = res.get("stderr", "")
            if not out and err:
                return f"[stderr] {err}"
            return out if out else f"[completed,no-stdout] {res}"
        last = str(r.get("error", r))
        if "not found" in last:
            time.sleep(5)
        else:
            time.sleep(3)
    return f"[dao] unreachable: {agent} :: {last}"

def dao_raw(cmd, agent="ZHOUMAC", timeout=30):
    r = api("POST", "/api/exec-sync", {
        "agent_id": agent, "cmd": cmd, "timeout": timeout
    }, timeout=timeout + 15)
    return r.get("result", {}) if r.get("status") == "completed" else r

if __name__ == "__main__":
    print("HEALTH:", json.dumps(health(), ensure_ascii=False))
    print("AGENTS:", json.dumps(agents(), ensure_ascii=False, indent=2))
