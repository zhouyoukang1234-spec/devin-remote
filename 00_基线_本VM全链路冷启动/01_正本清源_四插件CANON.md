# 正本清源 · 真·四插件 CANON

> 本档以 John（用户）2026-06-10 的口径校正为准，作为 `E:\DAO_ARCHIVE` 的**正本**。
> 反者道之动 —— 之前的 Agent 一度去追 GitHub `windsurf-assistant` 仓库的分支，
> 那是**子项目/辅助经验**，不是正本。真正的核心是下述四个插件，源码与历史都在本归档内。

---

## 一、四插件总览（这才是真正的核心）

| # | 插件 | 本质 | 归档位置 | 对应历史对话 |
|---|------|------|----------|--------------|
| 1 | **Proxy Pro**（dao-proxy-pro） | 在 Min 版基础上，外接各路第三方模型路由进 Windsurf/Devin Desktop 内使用 | `01_对_fc6d09ed\local_resources\dao-proxy-pro`（811 文件） | 01_对_fc6d09ed |
| 2 | **Devin 插件核心**（dao-vsix / Devin插） | 路由 Devin 官方网页 + Devin AI 全功能网页：把 Session / knowledge / playbook 等模块都收进这个插件 | `02_对_0c7c6948\local_resources\Devin插`（79 文件 53.5MB） | 02_对_0c7c6948 |
| 3 | **Claude·Cloudflare 独立插件**（dao-bridge / CF-DaoHub 产品化） | 做成插件形态，装进任意 VS Code 系 IDE，用户**登录自己的 Cloudflare 账号**即可全链路跑通整个流程 | `03_对_878766aa\local_resources\CF-DaoHub`（21 文件） + `repos\dao-bridge` | 03_对_878766aa |
| 4 | **Git 账号插件**（devin-git-auth） | 多个 Devin 账号连接到一个 GitHub（多账号→单 Git 鉴权统一管理） | `06_附插_devin-git-auth\devin-git-auth`（34 文件，含 devaid.devin-git-auth-2.0.0.vsix） | 06（独立板块） |

四插件「道并行而不相悖，万物并育而不相害」：同依赖一个软件本体（Windsurf / Devin Desktop），
各自独立的 VSIX 扩展，可并行构建、安装、测试；彼此「老死不相往来」，技巧性地各司其职。

---

## 二、逐插件本源需求（底层驱动力）

### 插件 1 · Proxy Pro
- **目标**：cc-switch 式的 Provider 代理面板，把外部第三方模型（各厂商 API）路由进 IDE 内当作可选模型用。
- **底层**：本地代理（实测端口 8937/8937 系），Provider CRUD、模型分层（Low/Med/High/XHigh/Max/Thinking）合并为单模型块以对齐 Cascade 选择器 UI、connect/disconnect 切换路由。
- **Min vs Pro**：本对话在新 VM 实测的是 `dao-proxy-min`(v9.8.0，反者道之动·帛书德道经 SP 注入)，**Pro 是 Min 的超集**（多了完整外接模型路由 + cc-switch UI + Provider 预设）。Pro 源码在 `01\local_resources`。
- **遗留**：拉 cc-switch（farion1231/cc-switch）真实 UI 与 Provider 预设参数；面板 2/3 精修；对 live proxy 跑 E2E；源码回写 141。

### 插件 2 · Devin 插件核心
- **目标**：在 IDE 内嵌入 Devin 官方网页路由 + Devin AI 全功能网页，把 Sessions / Knowledge / Playbook / Secret 等模块统一收进这一个插件。
- **底层**：逆向 devin.ai webview 登录机制（跟随 Devin Desktop 账号自动登录）；三账号同步（Devin Desktop ↔ 全能模块 ↔ 路由官方板）；全能模块对 devin.ai 官方功能逐项对齐（含增删改操作）。
- **遗留**：实路官方 webview 自动登录；三账号同步闭环；全能模块补全失增改操作；全链路环测 + 回写。

### 插件 3 · Claude·Cloudflare 独立插件
- **目标**：把 dao-bridge / CF-DaoHub（双机中继后端）**产品化成插件**：用户在任意 VS Code 系 IDE 安装后，登录**自己的 Cloudflare 账号**，即可一键拉起中继 + 全链路跑通。
- **底层**：dao-bridge VSIX（已构建并在 workers.dev 公网验证过）；CF 隧道/Durable Object 中继；conn.json + 开机自启。
- **现状（已完成的）**：dao-bridge VSIX 构建 + 公网 workers.dev 验证；新 PAT（zhouyoukang1234-spec）+ devin-remote 仓；修 UTF-8 BOM 根因并合 PR。
- **遗留**：把 dao-bridge 后端落到 141 `...\公PowerShell_Agent\CF-DaoHub`；云端逐能力验证（exec/file/read/write/ls/info）；登录 Cloudflare 账号的产品化 UI。

### 插件 4 · Git 账号插件（devin-git-auth）
- **目标**：多个 Devin 账号连接到一个 GitHub，统一鉴权管理。
- **底层**：`devaid.devin-git-auth` v2.0.0（已打包 VSIX）；activitybar 面板「Git Auth」+ webview「GitHub Auth」；CLI `dao-git-auth-cli.js`；大量 CDP/推送/安装调试脚本（`_*.js` / `_*.ps1`）。
- **现状**：VSIX 已存在于 `06_附插_devin-git-auth`，可直接安装验证。

---

## 三、windsurf-assistant 仓库的定位（辅助·非正本）

- GitHub `zhouyoukang/windsurf-assistant`（分支如 `feat/yin115-fanzhe-devin-vm`）是一个**子项目**，与上述四插件正本「没有太多联系」。
- 但其中一些核心板块（如**账号切换** wam/rt-flow、dao-proxy-min 的反代注入）可作为**经验吸收**进本归档，用于冷启动加速。
- 本对话已在新 VM 实测过该仓的 `dao-proxy-min`(v9.8.0) 与 `wam`(rt-flow v2.7.5)，验证了构建·安装·激活·账号轮换链路，成果固化在 `00_基线` 内。
- **告诫下一个 Agent**：不要把 windsurf-assistant 当成主线去逐分支翻找四插件——四插件正本就在本归档 01/02/03/06。windsurf-assistant 仅供借鉴。
