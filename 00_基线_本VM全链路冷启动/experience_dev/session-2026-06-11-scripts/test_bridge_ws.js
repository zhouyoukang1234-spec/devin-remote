// Harness: stub 'vscode' then drive dao-bridge extension.activate()
const path = require("path");
const os = require("os");
const http = require("http");
const fs = require("fs");
const Module = require("module");

const EXT = "C:\\Users\\Administrator\\plugins\\cf-daohub\\dao-bridge-ext\\extension.js";
const WS_ROOT = "C:\\Users\\Administrator\\dao";

// ---- vscode stub ----
const listeners = {};
const vscodeStub = {
  workspace: {
    workspaceFolders: [{ uri: { fsPath: WS_ROOT } }],
    name: "dao-test-workspace",
    getConfiguration: () => ({ get: () => "" }),
    openTextDocument: async (p) => ({ p }),
  },
  window: {
    registerWebviewViewProvider: () => ({ dispose() {} }),
    showInformationMessage: () => {},
    setStatusBarMessage: (m) => console.log("[statusbar]", m),
    showTextDocument: () => {},
  },
  commands: { registerCommand: () => ({ dispose() {} }) },
  env: { appName: "Devin Desktop", machineId: "test-machine", sessionId: "test-session", clipboard: { writeText: async () => {} }, openExternal: async () => {} },
  version: "1.110.1",
  Uri: { parse: (s) => s },
};
const origLoad = Module._load;
Module._load = function (req, parent, isMain) {
  if (req === "vscode") return vscodeStub;
  return origLoad.apply(this, arguments);
};

const ext = require(EXT);

const ctx = { subscriptions: [], extensionPath: path.dirname(EXT) };

(async () => {
  ext.activate(ctx);
  // wait for tunnel/url (activate kicks bridge.start internally; poll conn.json)
  const connPath = path.join(os.homedir(), ".dao", "bridge", "conn.json");
  let conn = {};
  for (let i = 0; i < 30; i++) {
    await new Promise((r) => setTimeout(r, 1000));
    try { conn = JSON.parse(fs.readFileSync(connPath, "utf8")); } catch (e) {}
    if (conn.url) { console.log("tunnel url captured at ~" + (i+1) + "s"); break; }
  }
  console.log("conn.json:", JSON.stringify(conn));
  const token = conn.token, port = conn.port;
  if (!port) { console.log("FAIL: no local port"); process.exit(1); }

  // test local workspace server endpoints
  function api(method, p, body) {
    return new Promise((resolve) => {
      const data = body ? JSON.stringify(body) : null;
      const req = http.request({ host: "127.0.0.1", port, path: p, method, headers: { Authorization: "Bearer " + token, "Content-Type": "application/json" } }, (res) => {
        let d = ""; res.on("data", (c) => (d += c)); res.on("end", () => resolve({ status: res.statusCode, body: d }));
      });
      req.on("error", (e) => resolve({ status: 0, body: String(e.message) }));
      if (data) req.write(data); req.end();
    });
  }
  const health = await api("GET", "/api/health");
  console.log("health:", health.status, health.body);
  const info = await api("GET", "/api/info");
  console.log("info.status:", info.status, "root:", JSON.parse(info.body).root);
  const noauth = await new Promise((resolve) => { http.get({ host: "127.0.0.1", port, path: "/api/info" }, (res) => { let d=""; res.on("data",c=>d+=c); res.on("end",()=>resolve(res.statusCode)); }); });
  console.log("info-without-token status (expect 401):", noauth);
  const exec = await api("POST", "/api/exec", { cmd: "cd" });
  console.log("exec(cd):", exec.status, JSON.parse(exec.body).stdout.trim());
  const ls = await api("POST", "/api/ls", { path: "." });
  console.log("ls(.) status:", ls.status, "items:", JSON.parse(ls.body).items.length);
  const escape = await api("POST", "/api/read", { path: "..\\..\\..\\Windows\\win.ini" });
  console.log("path-escape read status (expect 403):", escape.status);

  const md = fs.readFileSync(path.join(os.homedir(), ".dao", "bridge", "workspace.md"), "utf8");
  console.log("MD has URL line:", /URL:\s+https:\/\/.+trycloudflare/.test(md) || /URL:\s+\(/.test(md));
  console.log("MD bytes:", md.length, "| tunnel url:", conn.url || "(pending)");

  // lifecycle: deactivate should stop server
  ext.deactivate();
  await new Promise((r) => setTimeout(r, 1500));
  const afterStop = await api("GET", "/api/health");
  console.log("after deactivate health status (expect 0/closed):", afterStop.status);
  process.exit(0);
})();
