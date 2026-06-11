# 旧三对话核心精华提取

> 去芜留精 · 从 01/02/03 的 worklog + changes 中提取关键决策与代码成果
> 冗余数据（cloud_files + local_resources 共~74MB, ~1758 files）已移至 `_archive_bulk/`

---

## 01 · dao-proxy-pro (fc6d09ed) — 核心成果

**定位**: Windsurf 反向代理插件，拦截 IDE 请求路由到自定义 Provider
**关键决策**:
- 基于 Min 版本 extension.js 扩展而非从零写（保留代理核心，叠加 UI）
- 三面板架构: Panel1(EA总览) / Panel2(Provider管理) / Panel3(模型路由)
- 代理端口 8937（Windsurf内置 MITM proxy）
**核心代码**: `changes/` 中 36 个文件，主体 extension.js（~4000+ 行）
**遗留→已由07完成**: cc-switch预设引入✓、档位折叠✓、Provider CRUD✓、8937 E2E✓

## 02 · Devin 插件 / dao-vsix (0c7c6948) — 核心成果

**定位**: "Workspace as Server" + Devin Cloud 面板，把 IDE 变成 AI 可调用的后端
**关键决策**:
- 模块A: 路由官方网页（app.devin.ai webview）
- 模块B: Devin AI 全功能网页（sessions/knowledge/playbook/secret 自建 UI）
- 五步登录链: email/password → auth1 → sessionToken → orgId → apiKey → quota
- 端点发现: `performance.getEntriesByType('resource')` 抓 SPA 真实 API
- localhost:9920 workspace server（token dao-vsix-7e54e229ee3ddef7807d914f545d5b08）
**核心代码**: `changes/` 中 83 个文件，主体 src/extension.ts（4374+行）
**遗留→07已完成**: auth1解锁✓、v2sessions端点✓、proxy TLS修复✓、GUI登录✓；遗留: 中间面板渲染

## 03 · dao-bridge / CF-DaoHub (878766aa) — 核心成果

**定位**: Node agent + Cloudflare Workers DurableObject relay，让云端 AI 调用 141 本地能力
**关键决策**:
- 弃用 trycloudflare 免费隧道（不稳定/已卡死），改用 workers.dev DurableObject
- 五项能力: exec/ls/read/write/info，统一 JSON 协议
- UTF-8 BOM 修复（PR #44 已合并）解决 PowerShell 编码问题
- 中继: https://dao-relay-do.zhouyoukang.workers.dev/relay/141, Bearer dao141-9c2e7a1f4b6d8035
**核心代码**: `changes/` 中 54 个文件（agent.ps1, cf_cloud_agent.py, CLOUD_AGENT_GUIDE.md 等）
**遗留→07已完成**: 落地141✓、五项验证✓、自启固化✓、conn.json✓

---

## 旧三对话保留文件说明

每个旧对话目录（01/02/03）现仅保留:
- `worklog/worklog.md` — 完整决策日志（可搜索关键词还原上下文）
- `worklog/worklog.json` — 结构化事件流
- `changes/` — Devin 产出的最终代码文件（精华，可直接使用）
- `session_info.json` — 会话元数据
- `file_manifest.json` — 文件清单

已移除到 `_archive_bulk/`:
- `cloud_files/` — 原始云端快照（按 content key 存储，与 changes/ 重叠）
- `local_resources/` — 141 本地工程副本（已有原始路径 + 07 最新版本）
