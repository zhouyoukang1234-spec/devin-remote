"use strict";
// 验证 v9.9.262 · 首provider自动默认路由 · 无网络依赖
const fs = require("fs");
const path = require("path");
const os = require("os");

const ROUTER = "C:\\Users\\Administrator\\repos\\devin-remote\\plugins\\dao-proxy-pro\\vendor\\外接api\\core\\dao_router.js";

// 1) 准备一个「无路由」的干净配置 (模拟新用户)
const tmp = path.join(os.tmpdir(), "dao_autoroute_test_" + Date.now() + ".json");
fs.writeFileSync(tmp, JSON.stringify({
  gateway: { host: "127.0.0.1", port: 11435 },
  providers: {},
  daoRoutes: { enabled: true, substituteEnabled: false, routes: {} },
}, null, 2), "utf8");

const R = require(ROUTER);
R.init({ log: () => {}, configPath: tmp });

let pass = 0, fail = 0;
function ok(name, cond) {
  if (cond) { pass++; console.log("  PASS " + name); }
  else { fail++; console.log("  FAIL " + name); }
}

console.log("== 初始: 无任何路由 ==");
ok("SWE 1.6 Fast 初始未路由 → 走官方", R.shouldRoute("MODEL_SWE_1_6_FAST") === false);

console.log("== 添加首个 provider (deepseek) ==");
const r1 = R.hotAddProvider("deepseek", {
  apiKey: "sk-test", baseUrl: "https://api.deepseek.com/v1",
  models: ["deepseek-chat", "deepseek-reasoner"],
});
ok("hotAddProvider 返回 ok", r1.ok === true);
ok("自动默认路由 = deepseek/deepseek-chat (第一个模型)", r1.autoRoute === "deepseek/deepseek-chat");
ok("SWE 1.6 Fast 现在被路由", R.shouldRoute("MODEL_SWE_1_6_FAST") === true);
ok("小写连字符形式也命中", R.shouldRoute("swe-1-6-fast") === true);
ok("其它模型(Claude)仍走官方", R.shouldRoute("MODEL_CLAUDE_SONNET_4") === false);

console.log("== 添加第二个 provider (openai) · 不应覆盖用户首路由 ==");
const r2 = R.hotAddProvider("openai", {
  apiKey: "sk-test2", baseUrl: "https://api.openai.com/v1", models: ["gpt-4o"],
});
ok("第二provider不触发自动路由", r2.autoRoute === null || r2.autoRoute === undefined);
const cfg = R.hotGetConfig();
const sweRoute = cfg && cfg.daoRoutes && cfg.daoRoutes.routes
  ? cfg.daoRoutes.routes["MODEL_SWE_1_6_FAST"] : null;
ok("SWE 1.6 Fast 仍指向首provider deepseek", !!sweRoute && sweRoute.provider === "deepseek");

console.log("== 持久化检查 (异步写入·延迟读取) ==");
setTimeout(() => {
  const saved = JSON.parse(fs.readFileSync(tmp, "utf8"));
  ok("配置.json 已落盘 SWE 1.6 Fast 路由",
    !!(saved.daoRoutes && saved.daoRoutes.routes && saved.daoRoutes.routes["MODEL_SWE_1_6_FAST"]));
  try { fs.unlinkSync(tmp); } catch {}
  console.log("\n结果: " + pass + " passed, " + fail + " failed");
  process.exit(fail ? 1 : 0);
}, 400);
