"use strict";
// #4 parity test — Layer A: routed 3rd-party model receives the SAME 25 Cascade
// tools + system prompt and honors tool-calling, via the proxy's OpenAIChatAdapter.
const https = require("https");
const fs = require("fs");
const path = require("path");
const CORE = "C:\\Users\\Administrator\\repos\\devin-remote\\plugins\\dao-proxy-pro\\vendor\\\u5916\u63a5api\\core";
const dump = JSON.parse(fs.readFileSync(path.join(CORE, "_upstream_req_dump.json"), "utf8"));
const KEY = process.env.DEEPSEEK_API_KEY;
const tools = dump._tools; // 25 official Cascade tool defs (OpenAI function format)

// Try to load the real adapter to build the request exactly as the proxy does.
let buildBody;
try {
  const A = require(path.join(CORE, "adapters.js"));
  const adapter = (A.OpenAIChatAdapter || A.openaiChat || (A.adapters && A.adapters.openaiChat));
  if (adapter && typeof adapter.buildRequest === "function") {
    buildBody = (msgs, sys) => adapter.buildRequest({ model: "deepseek-chat", messages: msgs, tools, toolChoice: "auto", system: sys, stream: false });
    console.log("[adapter] using real OpenAIChatAdapter.buildRequest");
  }
} catch (e) { console.log("[adapter] load failed, fallback to manual:", e.message); }
if (!buildBody) {
  buildBody = (msgs, sys) => ({ model: "deepseek-chat", messages: (sys ? [{ role: "system", content: sys }] : []).concat(msgs), tools, tool_choice: "auto", stream: false });
}

const SYS = "You are a coding agent. When the user asks to read a file, you MUST call the Read tool with the file_path. Do not answer in prose.";
const messages = [{ role: "user", content: "Please read the file /tmp/example.txt and show me its contents." }];
let body = buildBody(messages, SYS);
// adapter may not inject system into messages for openai-chat; ensure it's present
if (!body.messages.some((m) => m.role === "system")) body.messages = [{ role: "system", content: SYS }].concat(body.messages);
const data = JSON.stringify(body);

const r = https.request({ hostname: "api.deepseek.com", path: "/v1/chat/completions", method: "POST", headers: { "Content-Type": "application/json", Authorization: "Bearer " + KEY, "Content-Length": Buffer.byteLength(data) }, timeout: 45000 }, (res) => {
  let d = ""; res.on("data", (c) => (d += c)); res.on("end", () => {
    console.log("STATUS", res.statusCode, "| toolsSent", tools.length);
    let j; try { j = JSON.parse(d); } catch { console.log("PARSE FAIL", d.slice(0, 300)); return; }
    const msg = j.choices && j.choices[0] && j.choices[0].message;
    const tc = msg && msg.tool_calls;
    if (tc && tc.length) {
      console.log("PASS  model emitted tool_call:", tc[0].function.name, "| args:", tc[0].function.arguments);
      console.log("PARITY: 3rd-party (DeepSeek) accepted all", tools.length, "Cascade tools + system, and called", tc[0].function.name);
    } else {
      console.log("NO tool_call. finish_reason=", j.choices && j.choices[0] && j.choices[0].finish_reason, "| content=", (msg && msg.content || "").slice(0, 200));
    }
  });
});
r.on("error", (e) => console.log("ERR", e.message));
r.on("timeout", () => { r.destroy(); console.log("TIMEOUT"); });
r.write(data); r.end();
