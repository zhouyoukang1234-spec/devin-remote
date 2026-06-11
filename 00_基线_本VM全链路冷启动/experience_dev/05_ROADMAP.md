# 统一体系与续开发路线图 (ROADMAP)

> 更新于 2026-06-10 · 基准: `07_session_e0405e88\`
> 道生一，一生二，二生三，三生万物 —— 四插件本是同一套「让外部 AI 安全连入本地 141 工作」的体系四面。

## 一、四插件的本质关系

- **dao-proxy-pro (v9.9.261)**：Windsurf/VS Code 侧「反向代理插件」(IDE→HTTP API + relay 出网桥)，含 cc-switch 风格多 Provider 路由面板，14家预设。
- **dao-vsix (v1.0.3)**：Devin Cloud 桌面端插件，路由官方网页 + Devin AI 全功能网页（sessions/knowledge/playbook/secret）。auth1 五步登录链已通。
- **dao-bridge / CF-DaoHub**：Node agent 在 141 运行，经 Cloudflare Workers DurableObject relay 暴露五项能力(exec/ls/read/write/info)给云端。已固化。
- **devin-git-auth (v2.0.0)**：多 Devin 账号 → 一个 GitHub 的连接器插件，独立 VSIX。

共享基础: **workers.dev relay** + 141(DESKTOP-MASTER) 执行端 + 统一 `/api/*` 协议。

## 二、统一架构
```
[云端 AI / Devin]  ──HTTPS──>  [CF Workers DurableObject relay]  ──WS──>  [141 agent]  ──>  本地 IDE/Shell/文件
       ▲                                                                      │
       └────────── dao-proxy-pro (IDE内HTTP API+面板路由) ─────────────────────┘
       └────────── dao-vsix (Devin Cloud 面板: sessions/secrets/知识/playbook) ─┘
       └────────── devin-git-auth (GitHub PAT 统一鉴权) ───────────────────────┘
```

## 三、当前完成度（基于 07 的成果）

| 插件 | 核心功能 | 完成度 | 遗留 |
|---|---|---|---|
| dao-proxy-pro | 档位折叠/cc-switch预设/Provider CRUD/8937 E2E | 100% | GUI录屏验证 |
| dao-vsix | 登录链路(auth1五步)/API 5/5/Header状态 | 90% | 中间面板webview渲染(SyntaxError '&' + sw undefined) |
| dao-bridge | 落地141/五项能力/自启/conn.json | 100% | — |
| devin-git-auth | VSIX安装/面板UI | 80% | 真实PAT E2E |
| 跨项目 | GitHub推送 | 0% | 四插件推 zhouyoukang1234 |

## 四、续开发建议（给下一个 agent）

1. **冷启动**: 读 `07_session_e0405e88\HANDOFF.md`，按清单恢复环境
2. **优先修 dao-vsix 中间面板**: 搜 extension.ts 中 `rO(`、`v-overview`、`&#39;`；疑似 HTML 实体转义在 JS 字符串中被破坏
3. **录屏验证** dao-proxy-pro GUI 折叠效果（API 已通，视觉未录）
4. **devin-git-auth 真实 PAT E2E**: 用 $GITHUB_PAT 测试完整 Git 流程
5. **四插件推 GitHub**: owner zhouyoukang1234，每个插件独立 repo 或 monorepo
6. **统一 SDK**: 三套 relay/proxy 协议与 token 管理收敛为一个可复用模块（参考 07\code\vm-sdk\）
7. **WindSurf Assistant 子项目**: 仅吸收其账号切换经验，不合并
8. **wam 插件 / RT-FLOW**: 账号登录痛点的替代方案（wam 存账号、rt-flow 从 vscdb 读凭证），可参考但不必整合

## 五、核心坑速查（帛书·「正言若反」）

- computer工具丢Shift字符 → Set-Clipboard+ctrl+v
- db64出站中文GBK损毁 → 通配符路径；写文件走write141()
- 本地代理8937是明文HTTP → http模块；windsurf.com经代理502 → 直连优先
- trycloudflare隧道已死 → 只走workers.dev DurableObject
- SPA网页登录走cookie → API走Bearer auth1，不互通
