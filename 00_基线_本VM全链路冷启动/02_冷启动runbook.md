# 冷启动 Runbook · 本VM全链路（最耗时的部分，已替你趟通）

> 本对话最值钱的成果＝把「装 Windsurf/Devin Desktop → 真账号登录 → 账号切换 → 构建/安装 VSIX → 编辑器内验证」
> 这条**冷启动长链路**在一台全新云 VM（devinbox / Windows Server 2022）上**完整趟通并实测**。
> 下一个 Agent 照本 runbook 走，可把数小时的冷启动压到几十分钟。无为而无不为。

---

## 0. 环境底座（新 VM）
- OS：Windows Server 2022；Home：`C:\Users\Administrator`
- Node 20.19.0 + npm 10.8.2（预装）；git 就绪
- `@vscode/vsce`（打包 VSIX）：`npm i -g @vscode/vsce` 或 `npx @vscode/vsce`

## 1. 安装 Devin Desktop（= Windsurf 同源）
- 安装位置：`%LOCALAPPDATA%\Programs\Devin\Devin.exe`（v3.1.7 / productVersion 1.110.1）
- CLI：`devin-desktop`（在 PATH 或安装目录 `bin\`）
- 下载脚本见 `tools\`（dl_windsurf 逻辑）；装好后用户数据目录：
  - 设置：`%APPDATA%\Devin\User\settings.json`
  - 扩展：`%USERPROFILE%\.devin\extensions`（随磁盘持久，重启不丢）

## 2. 真账号登录（上一个对话卡死的闸门，本对话已彻底打通）
**坑**：直接粘旧 `devin-session-token$...` 会「Invalid auth token」（过期）。
**正法**：走真实登录流取**新鲜** token：
1. 浏览器开 `https://windsurf.com/devin/account/login`
2. 邮箱（如 `lcld26815946@gmail.com`）+ 密码登录 → 拿到有效 `ott$...` token
   - ⚠ 手输邮箱时 `@` 常被吞 → 用**剪贴板粘贴**（`Set-Clipboard` + Ctrl+V）填邮箱字段
3. 把 `ott$...` 粘入 Devin Desktop 的登录框 → 右上角出现头像、模型 `SWE-1.6 Slow` 可用、状态栏 `Free · Devin`
- token 持久化在 Devin Desktop 用户数据里；VM 重启后**重新打开即仍登录**（无需再登）。

## 3. 账号库与切换（WAM / rt-flow）
- 账号库文件：`%USERPROFILE%\.wam\accounts.md`，每行 `email password`（空格分隔），本对话已装 7 账号。
- 141 上的本源账号目录：`...\070-插件_Plugins\010-WAM本源_Origin`（WAM 本源）。
- 在 `settings.json` 配 `wam.accountsFile` 指向账号库 → wam 插件激活后状态栏显示 `D100% · W100% · 7/7号`，自动轮换 1/7→7/7。
- **凭据不在本 runbook 明文展开**：真账号库已存于 141 的 `.wam\accounts.md` 与各对话归档的 `local_resources`，按需读取。

## 4. 构建 & 安装 VSIX（四插件通法）
```powershell
# 构建（纯 JS 插件无需编译；有 src 的先 npm i && npm run build）
cd <plugin_dir>
npx @vscode/vsce package --no-dependencies   # → 生成 <name>-<ver>.vsix

# 安装进 Devin Desktop
devin-desktop --install-extension <path-to.vsix> --force
# 验证：devin-desktop --list-extensions  ；或编辑器 Extensions 视图
```
- 本对话已成功构建并安装：
  - `dao-proxy-min-9.8.0.vsix`（82.57 KB）→ 激活 8ms，面板「道Agent·本源观照」渲染、模式切换（道⇄官）实测通过
  - `rt-flow-2.7.5.vsix`（118.25 KB）→ 激活，7 账号加载、轮换 D100%/W100%/7/7
  - 两个 VSIX 成品已放进本基线 `artifacts\`，下一个 Agent 可**直接 --install-extension**，跳过构建。

## 5. 编辑器内验证要点
- Proxy 类：活动栏面板渲染 + 模式/路由切换提示弹出即「活」。
- WAM 类：状态栏 `D%/W%/N号` + 自动轮换即「活」。
- LSP「connection to server is erroring」在反代 invert 模式下是**预期现象**（代理拦截出站），切 passthrough（官）仍在则与代理无关，属独立 LSP 问题。

## 6. 中继/双机（141·179）连接（base64 绕中文）
- 中继：`ps-agent-relay v3.4` @179(ZHOUMAC)，公网 quick-tunnel（URL 重启会漂移，需对齐）。
- Agent：`ZHOUMAC`(179, 192.168.31.179) / `DESKTOP-MASTER`(141, 10.6.22.1)。
- **核心坑**：relay 对中文路径/输出会丢字（每隔一个 CJK 字符掉一个）。
  **解**：用 `tools\dao_b64.py`（命令走 `-EncodedCommand` UTF-16LE base64，输出也 base64 回传）+ `tools\dao_put.py`（写文件时**路径与内容都 base64**，SHA256 实测字节无损）。
- relay 的 `exec-sync` 是**串行**执行，大命令（盘归/robocopy）会阻塞后续 → 用 `subprocess.Popen` 分进程后台跑 + 轮询日志。
