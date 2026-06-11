import urllib.request, json, ssl, os, time, base64
for k in ('HTTP_PROXY','HTTPS_PROXY','http_proxy','https_proxy'): os.environ.pop(k,None)
os.environ['NO_PROXY']='*'
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
opener=urllib.request.build_opener(urllib.request.ProxyHandler({}), urllib.request.HTTPSHandler(context=ctx))
urllib.request.install_opener(opener)

RELAY="https://dao-relay-do.zhouyoukang.workers.dev/relay/141"
TOKEN="dao141-9c2e7a1f4b6d8035"

def relay(path, method="POST", inner_body=None, timeout=40):
    env={"path":path,"method":method}
    if inner_body is not None:
        env["body"]=json.dumps(inner_body)
    data=json.dumps(env).encode()
    req=urllib.request.Request(RELAY, data=data,
        headers={"Authorization":f"Bearer {TOKEN}","Content-Type":"application/json","User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36","Accept":"*/*"}, method="POST")
    try:
        return urllib.request.urlopen(req, timeout=timeout).read().decode("utf-8","replace")
    except urllib.error.HTTPError as e:
        return f"HTTP{e.code}: "+(e.read().decode('utf-8','replace') if e.fp else str(e))
    except Exception as e:
        return f"ERR: {e}"

print("1) health   :", relay("/api/health","GET")[:200])
print("2) info     :", relay("/api/info","GET")[:300])
print("3) exec     :", relay("/api/exec","POST",{"cmd":"hostname"})[:200])
tf="C:\\\\Users\\\\Administrator\\\\dao_bridge_test.txt"
print("4) write    :", relay("/api/write","POST",{"path":tf.replace('\\\\','\\'),"content":"dao-bridge E2E "+time.strftime("%H:%M:%S")})[:200])
print("5) read     :", relay("/api/read","POST",{"path":tf.replace('\\\\','\\')})[:200])
print("6) ls       :", relay("/api/ls","POST",{"path":"C:\\Users\\Administrator"})[:250])

