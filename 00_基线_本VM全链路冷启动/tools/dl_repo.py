import urllib.request, ssl, os, sys, io, tarfile
tok = os.environ.get("GITHUB_PAT","")
ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE

def dl(owner, repo, ref="main", dest=r"C:\Users\Administrator\plugins"):
    url = f"https://api.github.com/repos/{owner}/{repo}/tarball/{ref}"
    req = urllib.request.Request(url, headers={"Authorization":f"Bearer {tok}","User-Agent":"dao","Accept":"application/vnd.github+json"})
    print("GET", url)
    data = urllib.request.urlopen(req, timeout=120, context=ctx).read()
    print("bytes:", len(data))
    outdir = os.path.join(dest, repo)
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as t:
        members = t.getmembers()
        # strip top-level component (owner-repo-sha/)
        top = members[0].name.split("/")[0] + "/"
        for m in members:
            if m.name.startswith(top):
                m.name = m.name[len(top):]
            if not m.name:
                continue
            t.extract(m, outdir)
    print("extracted to", outdir)
    return outdir

if __name__ == "__main__":
    owner = sys.argv[1] if len(sys.argv)>1 else "zhouyoukang"
    repo = sys.argv[2] if len(sys.argv)>2 else "windsurf-assistant"
    ref = sys.argv[3] if len(sys.argv)>3 else "main"
    dl(owner, repo, ref)
