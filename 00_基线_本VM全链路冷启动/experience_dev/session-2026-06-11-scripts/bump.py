import io, json, sys
p = r"C:\Users\Administrator\plugins\dao-vsix\package.json"
t = io.open(p, encoding="utf-8-sig").read()
d = json.loads(t)
d["version"] = sys.argv[1]
io.open(p, "w", encoding="utf-8", newline="").write(json.dumps(d, indent=2, ensure_ascii=False))
print("version set to", d["version"])
