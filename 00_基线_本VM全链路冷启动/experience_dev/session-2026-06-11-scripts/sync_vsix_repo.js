"use strict";
const fs = require("fs");
const path = require("path");
const SRC = "C:\\Users\\Administrator\\plugins\\dao-vsix";
const DST = "C:\\Users\\Administrator\\repos\\devin-remote\\plugins\\dao-vsix";
fs.copyFileSync(path.join(SRC, "src", "extension.ts"), path.join(DST, "src", "extension.ts"));
fs.mkdirSync(path.join(DST, "media"), { recursive: true });
fs.copyFileSync(path.join(SRC, "media", "dao-rules.md"), path.join(DST, "media", "dao-rules.md"));
for (const base of [SRC, DST]) {
  const pf = path.join(base, "package.json");
  const p = JSON.parse(fs.readFileSync(pf, "utf8"));
  p.version = "1.0.8";
  fs.writeFileSync(pf, JSON.stringify(p, null, 2) + "\n", "utf8");
}
const rl = fs.readFileSync(path.join(DST, "media", "dao-rules.md"), "utf8").length;
const has = fs.readFileSync(path.join(DST, "src", "extension.ts"), "utf8").includes("\u9053\u6cd5\u7ea6\u675f\u00b7\u5e1b\u4e66\u89c4\u5219");
console.log("DONE rulesLen=" + rl + " extHasRules=" + has + " ver=1.0.8");
