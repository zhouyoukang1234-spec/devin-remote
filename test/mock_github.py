#!/usr/bin/env python3
"""Faithful in-memory mock of the GitHub REST endpoints dao uses.
Lets the REAL agent.ps1 (receiver) and dao-exec.ps1 (sender) run a full
round-trip locally, since raw api.github.com is blocked in the sandbox.
Also exposes /_control/* helpers for scripted scenarios (e.g. backlog inject).
"""
import json, re, threading, sys
from datetime import datetime, timezone, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

LOCK = threading.Lock()
ISSUES = {}
NEXT = {"n": 1}

def now_iso(offset_s=0):
    return (datetime.now(timezone.utc) + timedelta(seconds=offset_s)).strftime("%Y-%m-%dT%H:%M:%SZ")

def make_issue(body, labels, created_at=None):
    with LOCK:
        n = NEXT["n"]; NEXT["n"] += 1
        ISSUES[n] = {"number": n, "body": body, "labels": [{"name": x} for x in labels],
                     "state": "open", "created_at": created_at or now_iso(), "comments": []}
        return ISSUES[n]

class H(BaseHTTPRequestHandler):
    def log_message(self, *a):  # quiet
        pass

    def _send(self, code, obj):
        data = json.dumps(obj, separators=(",", ":")).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _body(self):
        ln = int(self.headers.get("Content-Length", 0) or 0)
        raw = self.rfile.read(ln) if ln else b""
        try:
            return json.loads(raw.decode("utf-8")) if raw else {}
        except Exception:
            return {"_raw": raw.decode("utf-8", "replace")}

    # ── GET ──
    def do_GET(self):
        u = urlparse(self.path); p = u.path; q = parse_qs(u.query)
        if p == "/user":
            return self._send(200, {"login": "daotest"})
        if p == "/_control/dump":
            with LOCK:
                return self._send(200, list(ISSUES.values()))
        m = re.match(r"^/repos/([^/]+/[^/]+)/labels/(.+)$", p)
        if m:
            return self._send(200, {"name": m.group(2)})
        m = re.match(r"^/repos/([^/]+/[^/]+)/issues/(\d+)/comments$", p)
        if m:
            n = int(m.group(2))
            with LOCK:
                iss = ISSUES.get(n)
                return self._send(200, iss["comments"] if iss else [])
        m = re.match(r"^/repos/([^/]+/[^/]+)/issues/(\d+)$", p)
        if m:
            n = int(m.group(2))
            with LOCK:
                iss = ISSUES.get(n)
                return self._send(200 if iss else 404, iss or {"message": "Not Found"})
        m = re.match(r"^/repos/([^/]+/[^/]+)/issues$", p)
        if m:
            want_label = (q.get("labels", [None])[0])
            want_state = (q.get("state", ["open"])[0])
            direction = (q.get("direction", ["asc"])[0])
            with LOCK:
                out = []
                for iss in ISSUES.values():
                    if want_state and want_state != "all" and iss["state"] != want_state:
                        continue
                    if want_label and want_label not in [l["name"] for l in iss["labels"]]:
                        continue
                    out.append(iss)
            out.sort(key=lambda x: (x["created_at"], x["number"]), reverse=(direction == "desc"))
            return self._send(200, out)
        return self._send(404, {"message": "Not Found", "path": p})

    # ── POST ──
    def do_POST(self):
        p = urlparse(self.path).path; b = self._body()
        if p == "/_control/inject":
            iss = make_issue(b.get("body", ""), b.get("labels", ["devin-cmd"]),
                             created_at=b.get("created_at"))
            return self._send(201, iss)
        if p == "/_control/reset":
            with LOCK:
                ISSUES.clear(); NEXT["n"] = 1
            return self._send(200, {"ok": True})
        m = re.match(r"^/repos/([^/]+/[^/]+)/labels$", p)
        if m:
            return self._send(201, {"name": b.get("name", "")})
        m = re.match(r"^/repos/([^/]+/[^/]+)/issues/(\d+)/comments$", p)
        if m:
            n = int(m.group(2))
            with LOCK:
                iss = ISSUES.get(n)
                if not iss:
                    return self._send(404, {"message": "Not Found"})
                c = {"id": len(iss["comments"]) + 1, "body": b.get("body", "")}
                iss["comments"].append(c)
                return self._send(201, c)
        m = re.match(r"^/repos/([^/]+/[^/]+)/issues$", p)
        if m:
            labels = []
            for l in b.get("labels", []):
                labels.append(l if isinstance(l, str) else l.get("name", ""))
            iss = make_issue(b.get("body", ""), labels or ["devin-cmd"])
            return self._send(201, iss)
        return self._send(404, {"message": "Not Found", "path": p})

    # ── PATCH ──
    def do_PATCH(self):
        p = urlparse(self.path).path; b = self._body()
        m = re.match(r"^/repos/([^/]+/[^/]+)/issues/(\d+)$", p)
        if m:
            n = int(m.group(2))
            with LOCK:
                iss = ISSUES.get(n)
                if not iss:
                    return self._send(404, {"message": "Not Found"})
                if "state" in b:
                    iss["state"] = b["state"]
                return self._send(200, iss)
        return self._send(404, {"message": "Not Found", "path": p})

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    srv = ThreadingHTTPServer(("127.0.0.1", port), H)
    print(f"mock-github on http://127.0.0.1:{port}", flush=True)
    srv.serve_forever()
