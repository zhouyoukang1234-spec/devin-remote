# 冷启动 · Linux VM 全生命周期实测（云端 Agent 自测体系）

> 范围：在**云端 Agent 自己的 Linux 虚拟机**上，从零跑通「装 Devin Desktop(linux-x64) →
> 装 dao-one mega → 真账号 OAuth 登录 → 原生 Cascade 端到端使用」整条链路，并围绕三个锚点
> 深度解构插件的连接/解锁/自愈行为。补 `cloud/coldstart/RUNBOOK_coldstart.md`（Windows 版）的
> **Linux + headless 缺口**，使后续 Agent 在云 VM 上也能高效复现、推演、演化。
>
> 本文为**决策/实测记录**（结论以同机实测为准，非推断）。对应实践版本：Devin Desktop
> linux-x64 **3.3.18**（内核 productVersion 1.110.1）+ dao-one **v2.18.2**（折入 dao-proxy-pro
> **v9.9.320** 治本修复）。

---

## 0. 一句话结论

v9.9.320 在全新 Linux 冷启动环境下三锚点全绿：**①连得上官方**（spawn-hook 启动期强制收敛 LS）、
**②全模型解锁**（108 目录预注入，原生 Cascade 选择器全量可选，非只剩 slow）、**③能自愈**
（杀反代后 60s watchdog 同端口自动复活重锚，零人工）。用户偶见的 "connection erroring" 是
**启动期 restart-ls 杀旧 LS 的瞬态**，数秒自愈，非持久故障。

---

## 1. Linux 冷启动步骤（与 Windows RUNBOOK 对应）

| 步 | Windows（RUNBOOK） | Linux VM（本文补） |
|---|---|---|
| 取 IDE | 更新 API `…/win32-x64-user/stable/latest` → `/VERYSILENT` 装 | 更新 API `https://windsurf-stable.codeium.com/api/update/linux-x64/stable/latest` → 取 `Devin-linux-x64-<ver>.tar.gz` → 解压 |
| 装插件 | `devin-desktop --install-extension *.vsix` | 解压 mega vsix 到 `~/.devin/extensions/dao.dao-one-<ver>/`（或 `--install-extension`） |
| 起 IDE | 安装器注册的 `devin-desktop` | `./devin-desktop --no-sandbox --disable-gpu --user-data-dir ~/.devin-userdata --extensions-dir ~/.devin/extensions <ws>` |
| 取账号 | rt-flow 切号（账号池在本地） | 经 DAO Bridge 内网穿透从用户机账号池取（见 §2） |
| 登录 | rt-flow 注入 / Auth0 门 | **headless 需手动令牌 + weaker encryption**（见 §3，本文重点） |

> 解压版（非安装器）启动**必带** `--no-sandbox`（云 VM 无 SUID sandbox 权限），`--disable-gpu`
> （无 GPU），独立 `--user-data-dir`/`--extensions-dir` 与用户环境隔离（道并行而不相悖）。

## 2. 取账号资源（不落库、不出明文）

账号池在用户机 `C:\Users\Administrator\.dao\accounts.json`（email:password）。云端 Agent 经知识条目
「DAO Bridge 内网穿透」拿当前可达 URL+token，`POST /api/exec` 读出后落到 VM 本地 `~/.wam/accounts-backup.json`
（`{accounts:[{email,password}…]}`）。**隧道 URL 会轮换**：遇旧地址打不通**只需重读知识条目**（插件
≤30s 反向注入新 URL），永不需找用户重发——见知识库「断线零人工自愈」。

## 3. ⚠️ headless Linux 原生登录两道坎（本文最大增量）

普通用户在标准桌面（有 keyring + 已注册协议）**不会遇到**；但云 VM / headless 必踩，记牢省时：

1. **`devin://` 协议未注册** → 浏览器 OAuth 成功后的 deep-link 回调无法落到手动启动的实例。
   **正解**：走官方 **"Provide Auth Token"** 手动令牌路径（success 页 → `try manual auth` →
   show-auth-code 出令牌）。令牌 **60s 一次性**，务必现取现贴。
   - 坑：IDE 里点 "Provide Auth Token" 会**另开浏览器并抢焦点**，你的 Ctrl+V 会落到 Chrome 而非
     IDE 输入框。顺序应为：点 Provide Auth Token → 浏览器出令牌 → 复制 → **切回 IDE 窗口** →
     粘进顶部 quick input → Enter。
   - 多次点击会各起新 OAuth `state`，旧令牌随之失效；只用**最后一次**调用对应的令牌。
2. **无 OS keyring** → 令牌被接受后存凭据时弹
   `An OS keyring couldn't be identified…`。**选 "Use weaker encryption"** 即完成持久化登录。

登录成功判据：状态栏由 `Devin: Login` 变为 `Free - Upgrade Now · Devin - Settings`；Cascade 顶部出现
`View Changelog`；模型选择器从 `None selected` 变为可选模型。

> 建议（可选优化）：dao-vsix 已有 rt-flow 切号/auth 注入底座；后续可让切号面板在 headless 下
> 直接驱动「Provide Auth Token + weaker encryption」一键化，免去手工令牌竞速。当前为环境差异、
> 不阻断，故仅记录。

---

## 4. 三锚点深度解构（用户最关切）

### 锚点 1 · 装完会不会连不上官方服务器？→ 不会

- **原生 Cascade 对话端到端连通**：发 `hi` → `Thought for 1s` → 真实回复，无 "connection erroring"；
  dao 面板同步自动备份对话。
- **内置自修复三层闭环**（这是"连不上"被治本的根）：
  ```
  ① spawn-hook（启动期拦 LS 进程参数，强制收敛到健康反代）
     --api_server_url:        https://server.codeium.com    → http://127.0.0.1:8985
     --inference_api_server_url: https://inference.codeium.com → http://127.0.0.1:8985
  ② restart-ls（settings 锚点变更即 pkill LS 让其带新地址重生）
  ③ watchdog（60s 兜底，反代死/旧即重起重锚）
  ```
- LS↔反代实测长连 ESTABLISHED：`127.0.0.1:47600 → 127.0.0.1:8985 (language_server)`。

> **排错口诀**：启动那一刻 windsurf.log 里的 `couldn't create connection (ECONNREFUSED <port>)`
> 看时间戳——若=启动瞬间，是 restart-ls 杀旧 LS 的**瞬态**，数秒内 LS 重生重连即消失，**别误判为持久
> 故障**。先 `curl 127.0.0.1:8985/origin/health` 看反代是否 alive，再 `ss -tnp | grep :8985` 看
> LS 是否已重连。

### 锚点 2 · 是不是只剩一个 slow 模型、其余没解锁？→ 否，全量解锁

- **原生 Cascade 模型选择器**展示完整目录：SWE-1.6 / Fast / Slow、Claude Opus 4.8、GPT-5.5，搜 `gpt`
  出一大批 GPT 家族 → **绝非只有 slow**。
- 机制层：`[modelUnlock] 已处解锁态 · 全模型自现`；`/origin/model_unlock` → `enabled:true,
  catalog_size:108, catalog_loaded:true`。

### 锚点 3 · 万一连不上能否自愈？插件能否内置自修复？→ 能

主动注故障 `POST /origin/_quit` 杀反代，观测 60s watchdog：
```
[activate]  watchdog 启 · 60s 自愈一周
[watchdog]  proxy 死/旧 · 重起 :8985      ← 检测死亡
[proxy]     started :8985 ... healthy      ← 同端口复活
[watchdog]  proxy 复活 · 锚定 :8985        ← 重锚 settings
[anchor]    already http://127.0.0.1:8985 · skip write (无为而治)
```
**零人工**，反代在 watchdog 周期内同端口复活并重锚，复活后 selftest 三路全绿（canon/route/unlock）。

---

## 5. 云端 Agent 自测速查（curl 锚点）

```bash
# 反代存活 + 模式
curl -s 127.0.0.1:8985/origin/health        # {ok,status:alive,mode:invert,ea_running:true}
# 模型解锁目录
curl -s 127.0.0.1:8985/origin/model_unlock  # {enabled:true,catalog_size:108}
# 外接路由/自检
curl -s 127.0.0.1:8985/origin/ea/status     # {ready,count,providers}
curl -s 127.0.0.1:8985/origin/selftest      # canon/route/unlock 三路 ok
# 自愈演练（会杀反代，watchdog 60s 内复活）
curl -s -X POST 127.0.0.1:8985/origin/_quit
# LS 是否已连反代
ss -tnp | grep 127.0.0.1:8985
```

> 注：用 SWE-1.6 等**官方模型**时 `/origin/ea` 计数为 0、`upstream:null` 属正常——官方模型经 Devin
> Cloud 鉴权直连，不走 origin 外接路由（ea 只计 BYOK 外接）。要观测外接路由需选已配 BYOK 的路由模型。
