# 交接 · 致下一个 Agent（看这一份就够上手）

> 一句话：四插件正本都在 `E:\DAO_ARCHIVE` 内（01/02/03/06）；冷启动长链路已在新 VM 趟通（见 `02_冷启动runbook.md`）；
> windsurf-assistant 仓库只是辅助子项目，别拿它当主线。绝利一源，用师十倍。

## 一、先读顺序（5 分钟上手）
1. `00_基线\01_正本清源_四插件CANON.md` —— 四插件到底是什么、在哪、什么本质。
2. `00_基线\02_冷启动runbook.md` —— 装 Devin Desktop / 登录 / 账号切换 / 构建安装 VSIX 的趟通步骤。
3. `00_基线\03_本对话成果与突破.md` —— 已经做到哪、踩过哪些坑、怎么绕。
4. `05_总_统体\STATUS.md` & `ROADMAP.md` —— 三个历史对话各自的「最后待办」清单（逐插件遗留）。
5. 具体插件源码：`01/02/03/06` 的 `local_resources\`。

## 二、四插件下一步该专注什么（核心重点）
- **① Proxy Pro**：拉 cc-switch 真实 UI/Provider 预设；面板 2/3 精修（模型分层合并对齐 Cascade）；对 live proxy 跑 E2E；源码回写 141。
- **② Devin 核心**：逆向 devin.ai 官方 webview 自动登录（跟随 Devin Desktop 账号）；三账号同步闭环；全能模块（sessions/knowledge/playbook/secret）对官方功能逐项补全增删改。
- **③ Claude·Cloudflare**：把 dao-bridge 产品化为「登录自己 Cloudflare 账号即用」的独立插件；后端落 141 `...\公PowerShell_Agent\CF-DaoHub`；云端逐能力验证。
- **④ Git-auth**：装 `06` 的 `devaid.devin-git-auth-2.0.0.vsix` 验证多 Devin 账号→单 GitHub 鉴权。

## 三、冷启动可直接复用（省时间）
- relay/双机：用 `00_基线\tools\dao_b64.py` + `dao_put.py`（中文字节无损）。先 `python dao_sdk.py` 验 179/141 在线。
- 安装成品插件：`devin-desktop --install-extension 00_基线\artifacts\<name>.vsix --force`（跳过构建）。
- 账号库：`%USERPROFILE%\.wam\accounts.md`（7 账号）+ 141 `010-WAM本源_Origin`。
- 登录：旧 token 过期就走 `windsurf.com/devin/account/login` 取新鲜 `ott$...`。

## 四、注意 / 戒律（道法约束）
- 配额（ACU）：前三个对话都死于 out_of_quota。**分批留 checkpoint，逐插件深入**，别四面同时强攻。
- relay 串行：大命令会堵队列，用后台进程 + 轮询。
- 中继基础设施只用不改；账号/PAT 用既有的，不轮换。
- 「沉水入火，自取灭亡」——不要逆着工具特性硬来（如硬在 relay 里塞中文路径，改用 base64）。

## 五、关键资源指针
- 中继：`ps-agent-relay v3.4`@179；Agent `ZHOUMAC`(192.168.31.179)/`DESKTOP-MASTER`(141,10.6.22.1)；token 默认 `dao-ps-agent-2026`（建议换强令牌）。
- GitHub：仓 `zhouyoukang1234`/`zhouyoukang`；PAT 用 secret `$GITHUB_PAT`（zhouyoukang1234-spec）。
- CF-DaoHub 后端：`...\公PowerShell_Agent\CF-DaoHub`（dao-bridge / cf_cloud_agent.py / CLOUD_AGENT_GUIDE.md）。
- 提取方法论与脚本：`04_提方与具\`（API 事件流 + 浏览器取证 + 141 本盘 三路提取）。
