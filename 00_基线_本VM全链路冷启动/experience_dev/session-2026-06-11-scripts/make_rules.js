"use strict";
const fs = require("fs");
const path = require("path");
const src = "C:\\Users\\ADMINI~1\\AppData\\Local\\Temp\\devin-remote.exe-overflows\\57091297\\content.txt";
let s = fs.readFileSync(src, "utf8");
const i = s.indexOf(">") + 1;
const j = s.lastIndexOf("</knowledge>");
let body = s.slice(i, j > 0 ? j : undefined).trim();
if (body.includes("chars truncated") || body.includes("truncation_notice")) {
  console.log("ABORT: body contains truncation marker"); process.exit(1);
}
const outDir = "C:\\Users\\Administrator\\plugins\\dao-vsix\\media";
fs.mkdirSync(outDir, { recursive: true });
const out = path.join(outDir, "dao-rules.md");
fs.writeFileSync(out, body, "utf8");
const back = fs.readFileSync(out, "utf8");
console.log("wrote " + out);
console.log("len=" + back.length + "  startsWithExpected=" + back.startsWith("\u4f60\u672c\u7121\u540d"));
