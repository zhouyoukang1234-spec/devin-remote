# 本次对话历程 · 2026-06-11（道法自然 · 无为而无不为）

> 目的：把本次对话从头到尾的目标、决策、问题与解法、最终状态完整记录，供下一个 agent 吸收后冷启动 + 高效接力。

## 0. 用户的本源诉求（贯穿全程）

围绕 `E:\DAO_ARCHIVE` 里**四个核心插件**，从最底层基础设施搭起，一次性推进到底：

1. **dao-proxy-pro**：底层隔离替换提示词 + 外接第三方模型路由进 Windsurf。要求 Cascade 显示全部模型且与 Windsurf 账号（免费/Pro）零冲突；未路由模型走官方 Cascade，仅被路由的走通道；首通道=SWE 基础版（仅通道检测），首次加第三方（如 DeepSeek）默认把 SWE 1.6 Fast 路由过去；面板②仿 CC Switch 加渠道，面板③连线面板右侧自动拉取渠道可用模型；后端补齐「引用历史对话 / 子代理快速上下文」等官方工具，让第三方模型与官方 100% 同步（含隔离替换后的提示词）。
2. **dao-vsix**：全功能面板（会话/知识库/Playbook 本地同步且跟随 Devin Desktop 账号）；路由官网并自动登录同账号；把 git 多账号绑定 + 内网穿透两板块并入主面板；每次启动删旧知识库/Playbook → 注入「穿透动态 MD」+「帛书道德经/阴符经规则」两板块，让 Devin Cloud 接管当前窗口，效果≈本地 Cascade。
3. **devin-git-auth**：多个 Devin 账号共享同一 GitHub 仓库协同。
4. **dao-bridge**：登录 Cloudflare 自动运转，**专穿当前 Devin Desktop 工作区**（非整机），随窗口启停，每次产出实时更新的 MD 文档供云端 A 级机连接。

后续用户进一步指令：**git-auth(#3) 暂缓**，其余一次性推进到底，全部同步到 141 `E:\DAO_ARCHIVE` 并给下一个 agent 做好交接；最后再把整个归档**从「按对话」重构为「按项目」**（本文件即该次重构的产物之一）。

## 1. 关键现实 / 起点

- 云端 VM 每次是全新的（未装 Devin Desktop、无插件源码）；**源码与经验全在 141 的 `E:\DAO_ARCHIVE`**。
- 141（DESKTOP-MASTER）**无法直连 GitHub**，且与云端 VM 之间走 **workers.dev 中继 + 分块 base64** 传输（见 `00_.../tools` 与冷启动 runbook）。
- 账号走 **rt-flow 账号池**注入，绕过浏览器 OAuth 回跳。

## 2. 推进历程（里程碑）

1. **冷启动趟通**：从 141 拉全 4 插件源码 + 文档 → 装 IDE。一开始误装 **Windsurf 1.13.3**（内核 1.106.0），登录/注入全不对劲；改装**官方 Devin Desktop 3.1.7**（productVersion 1.110.1）后恢复正常——**版本必须是 3.1.7**。
2. **dao-vsix 全功能面板修复**：中间面板空白，连环三 bug——① `document.write` 拼串里残留垃圾片段致 `SyntaxError: Unexpected token '&'`；② webview 的 `esc()` 误调服务端 `mpEsc` → `ReferenceError`；③ 用 Codeium 的 `devin-session-token$` 打 Devin API 返回 401/403。修法：删垃圾片段 + 自包含 `esc()` + **token 选择规则**（仅 `cog_` 前缀走 v1 API，否则用 auth1）。修后 Sessions 拉到 **104 条真实会话**。
3. **proxy-pro #1–#4**：#1 全模型显示（`MODEL_UNLOCK` 注入 109 模型，仅显示层、与 tier 无关）；#2 仿 CC Switch + 连线面板自动拉模型；#3 首加渠道自动建 `SWE 1.6 Fast → 渠道首个模型`（单测 9/9）；#4 用真实 DeepSeek key **三层 E2E 全过**（Layer A 25 工具+system 透传含 `trajectory_search`/`skill`；Layer B `cascade_wire` 解码 44/44；Layer C 完整 `dao_router.route()` 管线→DeepSeek→重编码 Cascade 帧）。**最担心"工具缺失"的一块确认完整透传。**
4. **dao-vsix 帛书规则板块**：抽 proxy-pro 的「帛書老子 + 道藏陰符經」**7758 字**入 `media/dao-rules.md`，启动注入链 upsert（删旧→注新）；实测注入 200、知识库 16→17。
5. **dao-bridge v2.0.0 产品化**：从「整机 relay」改为**工作区专属隧道**：`WorkspaceServer` 暴露 `/api/{health,info,exec,ls,read,write}`，每个路径操作经 `withinRoot()` 限制在工作区根；`activate(onStartupFinished)` 拉起 `cloudflared --protocol http2 --url ...` 抓取 quick-tunnel URL，`deactivate()` 关窗即杀；每次启动重写 `~/.dao/bridge/conn.json` + `workspace.md`。
6. **dao-vsix v1.0.9 内网穿透板块**：`readBridgeConn()` 读 conn.json，hub 概览渲染「内网穿透 · DAO BRIDGE」板块（状态/公网URL/工作区/根目录/更新于 + 复制/打开）。
7. **Devin Desktop 3.1.7 内 live E2E**：隧道随 IDE 启动自动打通 → 集成终端访问**公网 URL** 返回 `{status:ok,workspace:devin-remote}` → dao-vsix 板块显示同一 URL → 关 IDE 隧道消失（公网转 CF 530）。录屏留证。
8. **同步与交接**：成果推 GitHub（PR #47 已合并→ 新成果走 **PR #48** 已合并 main）；全量同步到 141 `E:\DAO_ARCHIVE`（分块中继，zip 字节校验一致）；写 HANDOFF.md/LIVE_TEST。
9. **按项目重构归档**（本次最后）：顶层由「按对话」改为「按项目」——四插件各独立目录 + `00` 交接区 + `_attic_raw_archive` 收纳旧档。

## 3. 八条踩坑战例（精华）

1. **IDE 版本**：必须 Devin Desktop **3.1.7**，不是 Windsurf 1.13.3。版本错→登录/注入全乱。
2. **dao-vsix 面板空白**：垃圾片段语法错 + `esc()`/`mpEsc` + token 选错（见上 §2.2）。
3. **Devin API token 三件套**：`devin-session-token$`(Codeium 用，打 Devin API→403) / `auth1`(Devin API→200) / `cog_...`(v1 API→200)。规则：仅 `cog_` 走 v1，否则用 auth1。
4. **cloudflared QUIC/UDP 被本 VM 屏蔽**：默认 quic → `failed to dial to edge` / CF 1033。**必须加 `--protocol http2`** 强制走 TCP。勿删。
5. **Cloudflare 1010**：非浏览器 UA 被拒；客户端一律带 `Mozilla/5.0 ...` 浏览器 UA。
6. **vsce 版本**：旧的 vsce 2.15.0 不认 `--skip-license`；复用 dao-vsix 的 `@vscode/vsce`（新版）打包。
7. **PTY 多行命令被打断**：PowerShell here-string 经 PTY 易乱；改「写脚本到文件 → `-CmdFile` 执行」。
8. **141 无法直连 GitHub**：用 **分块 base64 中继**（zip→base64→60KB 切片→中继→141 重组→解码→解压）。

## 4. 中文编码注意（重构归档时新发现）

经中继 `-CmdFile` 下发的 PowerShell 脚本里若含**中文字符串字面量会被破坏**（New-Item 报"路径含非法字符"）。
解法：脚本里**只用 ASCII**；要写中文内容的文件，用 `base64(UTF8 bytes)` 内嵌脚本后 `[IO.File]::WriteAllBytes` 落地；要操作中文命名的目录，用 ASCII 前缀通配（如 `00_*`）解析出对象再 `-LiteralPath` 操作，**不要手打中文路径**。

## 5. 最终状态

- proxy-pro #1–#4 ✓（含 #4 真实 DeepSeek 三层 E2E）；dao-vsix v1.0.9 ✓；dao-bridge v2.0.0 ✓（live E2E）。
- git-auth：16 账号此前已绑同一 GitHub App（绑定目标态达成）；刷新「全新活跃 OAuth 连接」需 github.com 网页登录/设备码——**本轮按指令暂缓，源码完整归档于 `devin-git-auth/`**。
- GitHub：PR #48 合并入 main。
- 141：`E:\DAO_ARCHIVE` 已按项目重构完成。

## 6. 待办 / 下一步

- git-auth #3：彻底打通「多账号共享同一仓库活跃协同」（需网页登录/设备码）。
- proxy-pro UI 文案细化；dao-vsix 官网自动登录的 live 录屏复验。
- 密钥轮换：DeepSeek / GitHub PAT / Cloudflare token（均未入库）。
