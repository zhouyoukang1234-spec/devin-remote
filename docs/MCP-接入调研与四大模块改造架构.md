# MCP 接入调研 · 四大模块改造架构 · 内网穿透回退 · 对话备份完善

> 调研结论 + 落地架构 + 分阶段计划。道法自然 · 先把"能不能、怎么接"彻底查清, 再动手。

---

## 一、核心问题：Devin 云端 Agent 到底能不能用"本地 MCP"？

### 结论（确定）

| 传输类型 | 注入到 Devin Cloud 账号后, MCP 进程在哪运行 | 能否操作用户本地电脑 |
|---|---|---|
| **STDIO**（`npx`/`uvx`/`docker`） | **Devin 云端 VM 上**（相对 Agent 而言的"本地"= 云端机器） | **不能**。它在云端跑, 碰不到你电脑的浏览器/文件 |
| **HTTP (Streamable HTTP)** | 远程 URL（你给的 `serverUrl`） | **能**。把本机 MCP 经内网穿透暴露成公网 URL, 云端 Agent 走 HTTPS 调它 |
| **SSE**（旧） | 远程 URL | 能（已被官方标记 deprecated, 用 HTTP） |

**一句话**：你担心的"反向注入看不到能正常注入本地 MCP"是对的——**STDIO 形态注入进去是在云端跑的, 没用**。
正解是 **HTTP 形态**：本机起一个 MCP 服务器 → 经 dao-relay/cloudflared 暴露成公网 `https://.../mcp` → 把这个 URL 当 **HTTP MCP** 反向注入到账号。云端 Agent 调用时：`Agent → HTTPS → 穿透隧道 → 本机 MCP 服务器 → 操作本地浏览器/电脑/IDE`。

### 关键发现：注入侧代码已经就绪

`core/dao-vsix/src/extension.ts` 的 `devinAddCustomMcp()`（约 6544 行）**已支持 HTTP/SSE 注入**：

```ts
} else { // HTTP / SSE: 远程 URL + 可选鉴权头
  payload.url = spec.url || '';        // 例: https://dao-relay-do.../relay/rtflow/mcp
  if (spec.headers) payload.headers = spec.headers;  // 例: { Authorization: "Bearer <token>" }
}
await devinJsonPost(DEVIN_APP + '/api/mcp/installations', { Authorization, 'x-cog-org-id' }, payload);
```

代码注释原文：*"HTTP / SSE: 远程 URL + 可选鉴权头 (用于追录本地 141 经 dao-relay 暴露的公网端点)"* —— 说明这套就是按"本机经隧道暴露 → 注入 URL"设计的, **注入这一环已经能用**。

### 那缺的是什么？

缺的是**本机这一侧目前只暴露了普通 REST API**（`/api/exec`、`/api/file` 等），**还不是 MCP 协议端点**（MCP 用 JSON-RPC over Streamable HTTP, 端点 `/mcp`, 要实现 `initialize` / `tools/list` / `tools/call`）。
所以"四大模块改 MCP"= 在本机桥上**新增一个 MCP Streamable-HTTP 服务器**, 把四大模块的能力登记成 MCP tools, 挂到 `/mcp`, 复用现有隧道。

### 权限前提（需你确认一次）

官方文档：添加自定义 MCP 需要 **"Manage MCP Servers"** 权限（org admin）。本面板里每个 Devin 账号通常各自是自己 org 的管理员, 代码里 `/api/mcp/installations` 也确有成功记录——但请你确认你的账号能在官网"Add a custom MCP"（看得到这个按钮即有权限）。若个别账号无权, 该账号就只能走非 MCP 的兜底（见第四节）。

---

## 二、落地架构（四大模块 = 一个本地 HTTP MCP）

```
┌────────────────────────────────────────────────────────────────┐
│  Devin Cloud 账号 (反向注入: HTTP MCP, url=隧道/mcp, header=Bearer)│
└───────────────┬────────────────────────────────────────────────┘
                │ HTTPS (MCP / JSON-RPC over Streamable HTTP)
                ▼
        dao-relay (workers.dev)  ──出站 WSS──┐
                                             ▼
                                   本机 bridge (Node, 9920)
                                   ├── /api/*   ← 现有"整机直连"REST(保留=内网穿透本源)
                                   └── /mcp     ← 新增 MCP Streamable-HTTP 服务器
                                                  tools:
                                                  · browser.*  (本地 Chrome CDP 29229)
                                                  · pc.*       (exec/ls/read/write/search/edit)
                                                  · ide.*      (code CLI / VSCode 扩展桥)
                                                  · plugin.*   (切号/备份/注入/额度…)
```

- **内网穿透回退本源**：`addons/dao-bridge` 本就是"一台本机经 relay 暴露"的纯整机直连（`/api/exec` 等）。回退 = 不再往桥里塞四大模块抽象, 桥只当"哑管道"暴露整机; 四大模块能力统一搬到 `/mcp` MCP 服务器。两者同端口同隧道, 互不干扰。
- **浏览器**：本地 MCP 直接驱动本机 Chrome CDP（`29229`）, 不再需要张局自研的浏览器反代架构——正如你所说"浏览器 MCP 就可以完全用本地的 MCP 去操作了"。
- **一处暴露, 全账号复用**：所有账号注入同一个 `/mcp` URL + token, 隧道 `(session,token)` 隔离。

### 兜底（若某账号无 MCP 权限或想更省事）

1. **Knowledge 注入**：把"如何经隧道 REST 调用本机"（即你给的接入总文档）作为 Knowledge 反向注入, 让 Agent 用 `web`/`shell` 直接打隧道 REST——无需 MCP 权限, 但 Agent 体验不如原生 MCP tools。
2. **MCP 套 MCP**：用一个公网常驻的"网关 MCP"再回连本机, 等价于直接 HTTP MCP, 不划算。
故**首选 HTTP MCP, Knowledge 注入作兜底**。

---

## 三、对话备份机制完善（吸取手机版要点）

来自你手机版截图的要点, 映射到 `core/rt-flow`（Devin Cloud 备份本体）：

1. **先备份后清理, 且备份完整**：清理前必须确认全量备份完成; 备份产物应是"该对话所有 Session + 所有产出文件构成的文件夹", **不只是一份 MD**。
2. **"清理"实为"归档"且水过无痕**：被清理对话只归档不真删, 切号面板仍可见归档对话（保留此功能便于核查）。真正解决"清理"语义。
3. **清理触发条件收紧**：仅当"额度低于阈值 **且** 24h 内无更新"才自动清理; 运行中/近期有更新的对话**永不**自动清理。自动备份持续进行, 清理后**不移出账号库**（仅用户手动移出）。
4. **云端/本地数据源无感切换 + 标记**：对话已全量备份且 24h 无更新 → 切号面板优先读**本地备份**数据源, 并标记"云端/本地"; 一旦该对话有新更新 → 回退云端并增量更新。即使云端对话被清理, 面板查看对话信息也无感替换为本地备份源, 操作逻辑与之前完全一致。
5. **备份页 UI**：做成"下载列表悬浮窗", 位置在面板"刷新"与"下载"按钮之间; 支持按账号/对话名快速检索, 并一键拉取该对话的全部备份成果。

---

## 四、分阶段计划

- **阶段0（已完成·已合并）**：切号面板"每隔几秒整页重渲"根治（结构签名门）。PR #325, 三模块已发版。
- **阶段1**：本机 `/mcp` MCP Streamable-HTTP 服务器骨架（`initialize`/`tools/list`/`tools/call`）+ 先登记 `pc.*`（复用现有 `/api/exec` 等）；本地自测一个 MCP 客户端能 `tools/call`。
- **阶段2**：补齐 `browser.*`（本地 CDP）、`ide.*`（code CLI/扩展桥）、`plugin.*`（切号/备份/注入）。
- **阶段3**：反向注入面板增"注入本机 HTTP MCP"一键项（url=隧道/mcp + Bearer），跑通一个账号的端到端 Agent 调用。
- **阶段4**：对话备份机制按第三节 1~5 改造（最大单项）。
- **阶段5**：dao-bridge 文档/抽象回退为纯整机直连本源, 四大模块能力统一收口到 `/mcp`。

> 阶段1~3 是"四大模块改 MCP"的主体; 阶段4 是独立的大工程。建议确认优先级后逐阶段推进、每阶段一个 PR。

---

## 五、活体实测结论（本会话经 bridge 端到端验证 · 找到"接不上"的真因）

**结论先行：本机→云端 MCP 的整条链路在协议层"已经通"，"接不上"的真因是快速隧道 URL 轮换导致云端账号注入的是一个"已死的旧隧道地址"。**

### 5.1 已活体验证为「通」的环节

| 环节 | 证据 |
|---|---|
| 本机 MCP 服务器在跑 | `127.0.0.1:9100` LISTENING（`mcp_http.py`，`C:\dao_vm`），GET 返回 `{service:dao-bridge-mcp, transport:streamable-http, tools:26}` |
| 公网隧道可达 | `mcp_public.json` 当前 URL `https://plains-gear-knitting-pursue.trycloudflare.com/mcp` GET 200 |
| MCP 协议完整 | 经公网 URL 实打 `initialize`(协议版本 2024-11-05) / `tools/list`(26 工具，schema 正确) 全过 |
| 真控用户电脑 | 经公网 `tools/call` → `pc_desktop_info` 返回 2560×1440·Administrator；`pc_exec hostname` 返回 `DESKTOP-MASTER` —— 即任意远端 MCP 客户端(=Devin 云端)走 `HTTPS→隧道→本机`真能操作这台机器 |
| 注入侧已落地 | 账号 `org-733123013e` 的 `/api/mcp/servers` 中确有 `DAO Bridge MCP`(transport=HTTP, is_enabled=true) |
| 自愈循环已实现 | `daoSyncDaoMcpIntoProfile`(读 mcp_public.json) + `reinjectBridgeToAllAccounts`(URL 变→先删后建) + `bridgeWatchForReinject`(fs.watch) |

### 5.2 真因：云端注入的是「死链」

实测发现：账号里注入的 MCP URL = `https://wet-groups-flex-novel.trycloudflare.com/mcp`（**GET 空响应=隧道已死**），而本机当前活隧道是 `plains-gear-knitting-pursue`。**隧道轮换了，账号没跟着更新** → 云端 Agent 拿着死地址，自然"用不了"。

为什么没自愈：`fs.watch` 只有在「隧道轮换的那一刻恰有 dao-vsix 窗口开着」才会触发；若轮换发生在没有 dao-vsix 窗口时，事件丢失，直到下次激活才补注。且 `reinjectBridgeToAllAccounts` 只遍历 `dao-accounts-auth.json`（本机当前仅 1 个账号有可用 auth1），rt-flow 缓存里的其它账号不在覆盖范围。

### 5.3 已做的修复（本会话）

1. **即时修复**：已把死链删除、把当前活 URL(`plains-gear…`)重注进账号 —— 复验 `/api/mcp/servers` 现为活 URL。
2. **自愈兜底**（dao-vsix 3.17.13）：新增 90s 周期巡检 `bridgeScheduleReinject('poll')`，签名门控（URL/Token 未变=零成本空转）。即使 fs.watch 漏事件，开着窗口时最迟 90s 内云端地址自愈到活隧道。

### 5.4 "完美·无感·和官方同等"的根治方向（建议）

快速隧道天生 URL 轮换，是一切滞留的根源。要达到"和官方云端 MCP 同等(地址恒定、装一次永久可用)"，应**消灭 URL 轮换**：

- **首选：固定域名的命名隧道(named tunnel)**。把 `/mcp` 收口到 bridge 那条隧道(bridge 已支持 `named-tunnel.json`/`tunnel-token`)，bridge 反代 `/mcp → 127.0.0.1:9100`。这样 MCP 与 bridge 共用一个**恒定** `https://<固定域名>/mcp`，注入一次永不滞留。需用户提供一次 Cloudflare 隧道凭证(cert.pem 或 tunnel token)。
- **次选**：继续快速隧道 + 本会话的 90s 自愈兜底（已上线），可用但每次轮换有最长 ~90s 的空窗，且要求开着 dao-vsix 窗口。
- **附带建议**：把 `reinjectBridgeToAllAccounts` 的账号来源从仅 `dao-accounts-auth.json` 扩到 rt-flow `auth_cache.json`，覆盖全部账号(多账号场景)。
