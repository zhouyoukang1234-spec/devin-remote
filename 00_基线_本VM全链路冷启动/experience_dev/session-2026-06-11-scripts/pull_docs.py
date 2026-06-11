import os, sys, io
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
import dao_sdk as d

BASE = "E:\\DAO_ARCHIVE"
OUT = r"C:\Users\Administrator\dao\archive_mirror"

docs = [
    r"07_session_e0405e88\HANDOFF.md",
    r"07_session_e0405e88\WORKLOG.md",
    r"05_总结_统一体系\INDEX.md",
    r"05_总结_统一体系\STATUS.md",
    r"05_总结_统一体系\ROADMAP.md",
    r"05_总结_统一体系\CORE_ESSENCE.md",
    r"05_总结_统一体系\RESOURCE_MANIFEST.md",
    r"00_基线_本VM全链路冷启动\01_正本清源_四插件CANON.md",
    r"00_基线_本VM全链路冷启动\02_冷启动runbook.md",
    r"00_基线_本VM全链路冷启动\03_本对话成果与突破.md",
    r"00_基线_本VM全链路冷启动\04_交接_下一个Agent.md",
    r"00_基线_本VM全链路冷启动\05_补充_e0405e88成果整合.md",
    r"00_基线_本VM全链路冷启动\README.md",
    r"06_附加插件_devin-git-auth\NOTE.md",
]

for rel in docs:
    rp = BASE + "\\" + rel
    txt = d.fread(rp, "141")
    safe = rel.replace("\\", "__")
    lp = os.path.join(OUT, safe)
    with open(lp, "w", encoding="utf-8") as f:
        f.write(txt if isinstance(txt, str) else str(txt))
    print(f"{len(txt) if isinstance(txt,str) else 'ERR'}\t{safe}")
