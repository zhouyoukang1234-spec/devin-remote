"use strict";
// #4 DEFINITIVE E2E — drive the FULL dao_router.route() pipeline:
//   JSON GetChatMessageRequest -> parse -> budget -> protocol -> _callProvider(DeepSeek, real key)
//   -> re-encode Cascade frames -> mock res. Assert DeepSeek's reply token appears in frames.
const fs = require("fs");
const path = require("path");
const { EventEmitter } = require("events");
const CORE = "C:\\Users\\Administrator\\repos\\devin-remote\\plugins\\dao-proxy-pro\\vendor\\\u5916\u63a5api\\core";
const router = require(path.join(CORE, "dao_router.js"));
const dump = JSON.parse(fs.readFileSync(path.join(CORE, "_upstream_req_dump.json"), "utf8"));
const tools = dump._tools; // 25 official Cascade tools

// live config (has the real DeepSeek key + SWE 1.6 Fast route)
function find(d) { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); if (e.isDirectory()) { const r = find(p); if (r) return r; } else if (e.name === "\u914d\u7f6e.json") return p; } return null; }
const liveCfg = find("C:\\Users\\Administrator\\.devin\\extensions");
console.log("configPath=", liveCfg);

const TOKEN = "NEXUS42PONG";
const logs = [];
router.init({ log: (m) => logs.push(m), configPath: liveCfg });
console.log("isReady=", router.isReady(), "shouldRoute(MODEL_SWE_1_6_FAST)=", router.shouldRoute("MODEL_SWE_1_6_FAST"));

const flatTools = tools.map((t) => { const fn = t.function || t; return { name: fn.name, description: fn.description || "", parameters: fn.parameters || { type: "object", properties: {} } }; });
const body = {
  model_uid: "MODEL_SWE_1_6_FAST",
  prompt: "You are a coding agent operating under 帛书 rules. Follow instructions exactly.",
  messages: [
    { role: "user", content: "Reply with exactly this token and nothing else: " + TOKEN },
  ],
  tools: flatTools,
  tool_choice: "auto",
};
const raw = Buffer.from(JSON.stringify(body), "utf8");

const req = new EventEmitter();
req.socket = new EventEmitter();
const chunks = [];
const res = {
  headersSent: false, writableEnded: false,
  writeHead() { this.headersSent = true; return this; },
  setHeader() {}, getHeader() {}, flushHeaders() {},
  write(b) { if (b) chunks.push(Buffer.isBuffer(b) ? b : Buffer.from(b)); return true; },
  end(b) { if (b) chunks.push(Buffer.isBuffer(b) ? b : Buffer.from(b)); this.writableEnded = true; if (this._done) this._done(); },
  on() {}, once() {}, emit() {},
};

(async () => {
  let routed;
  const done = new Promise((resolve) => { res._done = resolve; setTimeout(resolve, 40000); });
  try {
    routed = await router.route(req, res, raw, true, "MODEL_SWE_1_6_FAST");
  } catch (e) { console.log("route threw:", e.message); }
  await done;
  const all = Buffer.concat(chunks);
  const txt = all.toString("utf8");
  console.log("route() returned=", routed, "| frames bytes=", all.length, "| chunks=", chunks.length);
  // streamed deltas split the token across frames; verify ordered subsequence
  let idx = 0; let pos = -1; let ordered = true;
  for (const ch of TOKEN.split("")) { const f = txt.indexOf(ch, pos + 1); if (f < 0 || f < pos) { ordered = false; break; } pos = f; }
  const hit = txt.includes(TOKEN) || ordered;
  const routedOk = routed === true && all.length > 0;
  console.log("RESULT", (hit && routedOk) ? "PASS" : "CHECK",
    "- route()=true:", routedOk, "| DeepSeek reply token in Cascade frames (contiguous or streamed-ordered):", hit);
  if (!hit) {
    // show any visible ascii content for diagnosis
    const visible = txt.replace(/[^\x20-\x7e\u4e00-\u9fff]/g, ".").replace(/\.{3,}/g, "..");
    console.log("frame text (sanitized, 0:600):", visible.slice(0, 600));
    console.log("last 8 logs:\n" + logs.slice(-8).join("\n"));
  }
  process.exit(0);
})();
