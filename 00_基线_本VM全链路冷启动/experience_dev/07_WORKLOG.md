# 对话 e0405e88 · 工作日志（四插件并行推进 → 归档交接）

> 会话: https://app.devin.ai/sessions/e0405e88c05b4a85bdeb96aae2c11790
> 时间: 2026-06-09 ~ 2026-06-10 · 环境: Devin 云VM (Windows Server 2022, devinbox)
> 哲学: 道法自然 · 帛书老子 · 阴符经

## 一、总体进度（Phase 0–2）

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase 0 | 环境搭建 + Windsurf 安装登录 (v1.110.1, John) | ✅ 完成 |
| Phase 1C | dao-bridge 落地 141 + 五项能力验证 + 自启固化 | ✅ 完成 |
| Phase 1A | dao-proxy-pro v9.9.261（档位折叠+cc-switch预设+Provider CRUD） | ✅ 完成（API E2E 通过） |
| Phase 1D | devin-git-auth 代码审查 (1211行 SYNTAX_OK) + VSIX 安装 + GUI面板验证 | ✅ 完成 |
| Phase 1B | dao-vsix v1.0.1→1.0.3（auth1解锁 + v2sessions + 登录修复） | ✅ 完成（API 5/5 + GUI登录成功） |
| Phase 2 | 四模块 GUI 集成测试 | ◐ 部分（登录链路全通；面板渲染遗留一个空白问题，见遗留） |

## 二、各插件最终状态

### 1. dao-proxy-pro（v9.9.261，已装入 Windsurf）
- Panel 3 同模型多档位折叠为单卡：gpt-5-4 ×4档 / swe-1-6 ×2档 / claude-*-thinking 变体，连线/断线作用于全部档位
- 路由双形归一：`MODEL_GPT_5_4_LOW` ↔ `gpt-5-4-low` 同视已连
- Panel 2 引入 cc-switch 风格预设库 14 家（DeepSeek/GLM/Kimi/百炼/SiliconFlow/MiniMax/OpenRouter/Anthropic…，baseUrl+默认模型取自 cc-switch 真实 presets）
- Provider CRUD 补全（增/改/删/模型列表编辑）
- 对本机实跑代理 8937 完成 API 级 E2E：4档一并路由✓、一并断开✓
- 源码: `code/dao-proxy-pro/extension.js`（约4775行）

### 2. dao-vsix / devin-plugin（v1.0.3，已装入 Windsurf）
- v1.0.1: `devinCanUseApi()` 接受 auth1 令牌（非仅 cog_），解锁全部面板 API
- v1.0.2: `devinListSessions` 修正端点 → `GET app.devin.ai/api/org-<bare>/v2sessions`（返回 `{result:[...]}`），API E2E 5/5 全通（sessions/secrets/playbooks/knowledge/git）
- v1.0.3: **登录关键修复** — `devinJsonPost/Get` 经本地代理(8937)时误用 https 连明文HTTP代理 → SSL wrong version → no_token。修复: ①127.0.0.1 走 http 模块 ②直连优先、status=0 时才降级走代理
- GUI 实测: Dao: Login Devin Cloud → "Devin login OK" + "Dao inject complete: Secret✓ Knowledge✓ Playbook✓"，面板头部显示 ✓lcld26815946 + barbba-287
- 源码: `code/dao-vsix/`（src/extension.ts 4374+行、package.json、build.js）

### 3. dao-bridge / CF-DaoHub（落地 141 运行中）
- 141 路径: `公共PowerShell_Agent\CF-DaoHub`；中继: `https://dao-relay-do.zhouyoukang.workers.dev/relay/141`，Bearer `dao141-9c2e7a1f4b6d8035`
- 五项能力 exec/ls/read/write/info 全部经 workers.dev 实测通过
- DaoBridge141 开机自启任务已注册；`~/.dao/conn.json` 自发现已写入
- VM 侧 SDK: `code/vm-sdk/dao_bridge.py`、`db64.py`（UTF-8 安全执行）

### 4. devin-git-auth（VSIX 已装，面板验证通过）
- 1211 行 SYNTAX_OK；GUI 面板正常渲染: GitHub PAT 保存/显隐、代理/直连、账号认证(邮箱+密码)、Git 操作(读取状态/连接/断开)、已认证账号列表
- 多 Devin 账号 → 一个 GitHub 的连接器定位确认

## 三、关键经验（盗机也，下一个agent必读）

1. **Devin API 端点全图（auth1 可用）**
   - 登录: `POST windsurf.com/_devin-auth/password/login` {email,password} → `{token:"auth1_..."}`（必须带 User-Agent，否则 CF 403）
   - org: `POST app.devin.ai/api/users/post-auth` → orgId/orgName
   - 列表: `GET app.devin.ai/api/org-<bare>/v2sessions|/secrets|/playbooks|/learning/all`，header `Authorization: Bearer auth1` + `x-cog-org-id: org-...`
   - token 类型: cog_(v1 API) / auth1(app API) / devin-session-token$(仅Codeium API，Devin API 403)
2. **SPA 登录 ≠ API 登录**: app.devin.ai 网页是服务端 cookie 会话（须走 Windsurf SSO），localStorage 注入无效；但扩展内 Bearer auth1 调 API 完全可行
3. **端点发现法**: SSO 登录 SPA 后用 `performance.getEntriesByType('resource')` 抓真实 API 调用（比 fetch 拦截器稳，F5 不丢）
4. **本地 MITM 代理坑**: 对 127.0.0.1 明文 HTTP 代理用 https.request 会 SSL wrong version number；代理转发 windsurf.com 还会 NGHTTP2_PROTOCOL_ERROR（502）→ 直连优先+降级策略
5. **账号登录麻烦的解法**: ①wam 插件（141 `C:\Users\Administrator\.wam\accounts.md` 存账号）②rt-flow 3.16.0 从 state.vscdb 读 windsurfAuthStatus（vscdb 原生二进制扫描，无需 Python）③本对话 dao-vsix 的五步链自动登录（email/password → auth1 → sessionToken → apiKey → quota）
6. **GUI 自动化坑（Devin computer 工具）**: 大写/Shift 字符（@、>、大写字母）经常被丢 → 一律 PowerShell `Set-Clipboard` + ctrl+v 粘贴
7. **db64 出站中文 GBK 损毁**: 出站命令避免中文字面量，用通配符路径；文件内容走 /api/write（JSON UTF-8 安全）
8. **141 文件读取**: `Get-Content -Encoding UTF8`
9. **VSIX 流水线**: `npx tsc -p . && node build.js && node --check out/extension.js` → `npx @vscode/vsce package --allow-missing-repository --skip-license` → `windsurf --install-extension x.vsix --force` → Reload Window
10. **CF-DaoHub trycloudflare 隧道已卡死**，弃用；一律走 workers.dev DurableObject 中继（必须带 User-Agent）

## 四、遗留问题（待续）

1. dao-vsix 全能模块中间面板登录后内容区空白（头部状态正常）：webview console 有 `Uncaught SyntaxError: Unexpected token '&'`（document.write 处）与 `sw is not defined`（onclick）→ 疑似 webview HTML 模板内引号/实体转义问题，下一步从 `getMiddlePanelHtml`/`rO()` 渲染函数排查
2. dao-proxy-pro GUI 档位折叠视觉验证未录屏（API E2E 已通）
3. devin-git-auth 实际 PAT 连接 E2E（面板 UI 已验证）
4. 四插件推送 GitHub（zhouyoukang1234，$GITHUB_PAT）未做

## 五、本机资源位置（VM devinbox）

- 插件源码: `C:\Users\Administrator\plugins\{cf-daohub, dao-proxy-pro, devin-plugin, devin-git-auth}`
- dao-vsix: `plugins\devin-plugin\dao-vsix`（v1.0.3 vsix 同目录）
- 桥接 SDK: `C:\Users\Administrator\dao_bridge.py`、`db64.py`
- 测试脚本: `test_1b_final.js`（5/5 API E2E）、`test_login_now.js`、`test_v2sess.js`
- Dao 工作区服务器: http://localhost:9920（token 见 ~/.dao）；代理 8937
