"use strict";
const fs = require("fs");
const src = "C:\\Users\\Administrator\\repos\\devin-remote\\plugins\\dao-proxy-pro\\vendor\\外接api\\core\\dao_router.js";
const dst = "C:\\Users\\Administrator\\.devin\\extensions\\dao-agi.dao-proxy-pro-9.9.261\\vendor\\外接api\\core\\dao_router.js";
if (!fs.existsSync(dst)) {
  console.log("DST not found, listing parent:");
  try {
    const p = "C:\\Users\\Administrator\\.devin\\extensions\\dao-agi.dao-proxy-pro-9.9.261\\vendor";
    console.log(fs.readdirSync(p));
  } catch (e) { console.log("parent err: " + e.message); }
  process.exit(2);
}
const before = fs.statSync(dst).size;
fs.copyFileSync(src, dst);
const after = fs.statSync(dst).size;
console.log("copied OK  before=" + before + "  after=" + after);
// sanity: confirm marker present
const has = fs.readFileSync(dst, "utf8").includes("首provider自动默认路由");
console.log("marker present in installed: " + has);
