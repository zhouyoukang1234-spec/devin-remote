# 00 · 当前基线 · 本VM全链路冷启动（两对话合流版）

> 更新：2026-06-10 · 来源：平行对话 5bc7c4a5 + 对话 e0405e88（工作一致，经验互补合流）
> 本文件夹是 `E:\DAO_ARCHIVE` 的**最新基线与入口**。旧三对话已归入 `_old_sessions\`，
> 下一个 Agent 从这里起步即可，专注四插件核心重点。无为而无不为，道法自然。

## 这里有什么
```
00_基线_本VM全链路冷启动\
  README.md                       # 本文件：入口与导航
  01_正本清源_四插件CANON.md        # 四插件正本（是什么/在哪/本质）
  02_冷启动runbook.md              # 装 Devin Desktop/登录/账号切换/构建安装 VSIX
  03_本对话成果与突破.md            # 平行对话(5bc7c4a5)成果与踩坑
  04_交接_下一个Agent.md            # 5分钟上手 + 逐插件下一步重点 + 戒律
  05_补充_e0405e88成果整合.md       # ★ e0405e88 增量成果（auth1 API链/dao-bridge/最新版本）
  06_bootstrap.ps1                # ★ 一键冷启动：环境检查→IDE检查→装四插件→验证（已实测）
  tools\                          # 可复用脚本（relay/base64/推文件）
    verify_channel.py             # ★ dao-bridge 通道一键体检（已实测 PASS）
    dao_sdk.py  dao_b64.py  dao_put.py
  artifacts\                      # ★ 可直接安装的最新成品
    dao-proxy-pro-9.9.261.vsix    # 插件① 最新（档位折叠+cc-switch+CRUD）
    dao-vsix-1.0.3.vsix           # 插件② 最新（auth1登录链+5/5 API）
    devin-git-auth-2.0.0.vsix     # 插件④ 最新
    rt-flow-3.16.0.vsix           # ★ 切号插件 基准版（用户指定 3.16.0 为基础）
    rt-flow-2.7.5.vsix            # 切号插件 旧实测版（7账号轮换 D100%/W100%）
    dao-proxy-min-9.9.64.vsix     # 插件① min最新版（from 141 origin 020）
    dao-proxy-min-9.8.0.vsix      # 插件① min基线版（保留参照）
    devin_user_settings.json      # Devin Desktop 用户设置样例
```

## 与归档其余部分的关系
- `07_session_e0405e88\` = 四插件**最新源码** + 测试脚本 + WORKLOG/HANDOFF（核心基准）
- `05_总览\` = INDEX / STATUS / ROADMAP / CORE_ESSENCE（旧三对话精华提炼）
- `06_附属插件_devin-git-auth\` = 插件④ 完整目录
- `dao_sessions_\` = 两个新对话的会话日志
- `_old_sessions\` = 旧三对话历史存档（01/02/03 worklog+changes；bulk 数据在 `_bulk_data\`）
- 插件③ dao-bridge 已**落地 141**: `公共PowerShell_Agent\CF-DaoHub`（开机自启，五能力可用）
- 141 本源插件目录（需补数据时来这里取）:
  - WAM/rt-flow 本源: `E:\道\道生一\一生二\Windsurf万法归宗\070-插件_Plugins\010-WAM本源_Origin`
  - dao-proxy-min: `...\070-插件_Plugins\020-道VSIX_DaoAgi\dao-proxy-min`（最新 9.9.64）
  - proxy 主线以 **proxy-pro 9.9.261** 为基础；rt-flow 以 **3.16.0** 为基础（用户指定）

## 冷启动三步（接入即开工）
1. 把本文件夹拷到新 VM → `powershell -ExecutionPolicy Bypass -File .\06_bootstrap.ps1`
2. `python tools\verify_channel.py` 验通 141 通道
3. 读 `05_补充` 的统一待办清单开工（首要：dao-vsix 中间面板 webview bug）
⚠ relay 串行：不要在经 relay 执行的 141 命令里再调 relay（会死锁超时）。

## 一句话给下一个 Agent
先读 `05_补充_e0405e88成果整合.md`（最新状态+统一待办）→ 再按 `02_冷启动runbook.md` 冷启动；
artifacts 里四个 VSIX 直接 `--install-extension` 免构建；141 通道用 dao-bridge（workers.dev relay）。
唯一硬遗留：dao-vsix 中间面板 webview 渲染 bug。绝利一源，用师十倍。
