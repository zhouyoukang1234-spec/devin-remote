"use strict";
const fs = require("fs");
const src = "C:\\Users\\Administrator\\repos\\devin-remote\\plugins\\dao-proxy-pro\\extension.js";
const dst = "C:\\Users\\Administrator\\.devin\\extensions\\dao-agi.dao-proxy-pro-9.9.261\\extension.js";
if (!fs.existsSync(dst)) { console.log("DST not found: " + dst); process.exit(2); }
const before = fs.statSync(dst).size;
fs.copyFileSync(src, dst);
const after = fs.statSync(dst).size;
const has = fs.readFileSync(dst, "utf8").includes("autoRoute");
console.log("extension.js copied  before=" + before + "  after=" + after + "  autoRoute=" + has);
