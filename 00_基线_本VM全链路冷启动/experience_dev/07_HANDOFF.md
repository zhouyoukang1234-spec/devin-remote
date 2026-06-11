# 交接指南 · 给下一个 Agent（冷启动手册）

> 来源对话: e0405e88（与另一平行对话工作完全一致，经验互补）
> 原则: 道法自然 · 无为而无不为 · 帛书老子+阴符经为代码注释风格

## 0. 一句话现状
四插件（dao-proxy-pro / dao-vsix / dao-bridge / devin-git-auth）核心功能全部开发完成并装入 VM 上的 Windsurf 实测，dao-vsix 已到 v1.0.3（Devin Cloud 登录全链路打通）；剩余为 GUI 细节修复、录屏验证与 GitHub 推送。

## 1. 冷启动清单（按顺序）

1. **141 通道**（最可靠，先验证）:
   `python C:/Users/Administrator/db64.py "hostname" 30` → 应回 DESKTOP-MASTER
   - 中继: https://dao-relay-do.zhouyoukang.workers.dev/relay/141 · Bearer dao141-9c2e7a1f4b6d8035 · 必须带 User-Agent
   - 141 端 DaoBridge141 开机自启；若不通，141 上重启 `公共PowerShell_Agent\CF-DaoHub`
2. **Windsurf**: VM 已装 v1.110.1 已登录(John)。若注销: 账号在 141 `C:\Users\Administrator\.wam\accounts.md`；email lcld26815946@gmail.com
3. **插件安装**: `windsurf --install-extension <vsix> --force` + Reload Window
   - dao-proxy-pro-9.9.261.vsix（plugins\dao-proxy-pro）
   - dao-vsix-1.0.3.vsix（plugins\devin-plugin\dao-vsix）
   - devin-git-auth（plugins\devin-git-auth）
4. **Devin Cloud 登录**: 命令面板 → "Dao: Login Devin Cloud" → 邮箱/密码（GUI 输入用剪贴板粘贴！直接 type 会丢 @ 等字符）→ 预期 "Devin login OK"
5. **验证 API**: `node C:/Users/Administrator/test_1b_final.js` → 5/5 通过

## 2. 立即可续的任务（优先级序）

1. **dao-vsix 中间面板空白修复**: 登录成功但内容区不渲染。线索: webview console `Uncaught SyntaxError: Unexpected token '&'` + `sw is not defined`。排查 src/extension.ts 中 webview HTML 生成（搜 `rO(`、`v-overview`、`&#39;`）— 疑似 HTML 实体转义在 JS 字符串中被破坏
2. dao-proxy-pro GUI 档位折叠录屏验证（API 已通：gpt-5-4×4 / swe-1-6×2 / thinking×2 折叠单卡）
3. devin-git-auth 真实 PAT E2E（PAT 用 $GITHUB_PAT）
4. 四插件推 GitHub（owner: zhouyoukang1234）
5. WindSurf Assistant 子项目（用户提示）: 仅吸收其"切换账号"等板块经验，不直接合并

## 3. 核心 API 速查（auth1 全可用）

```
POST https://windsurf.com/_devin-auth/password/login    {email,password} → {token:auth1_...}
POST https://app.devin.ai/api/users/post-auth           Bearer auth1 → {orgId,orgName}
GET  https://app.devin.ai/api/org-<bare>/v2sessions     Bearer auth1 + x-cog-org-id → {result:[...]}
GET  .../api/org-<bare>/secrets | /playbooks | /learning/all
GET  .../api/organizations/<orgId>/git-connections-metadata
```
全部请求必须带 User-Agent。org: barbba-287 / org-bb721a3ad45a4fe98a7c1c2f4bbba802

## 4. 已知坑速查
- computer 工具丢 Shift 字符 → Set-Clipboard + ctrl+v
- db64 出站中文 GBK 损毁 → 通配符路径；写文件走 write141()
- 本地代理 8937 是明文 HTTP → http 模块；windsurf.com 经代理 502 → 直连优先
- trycloudflare 隧道已死，勿用；只走 workers.dev
- SPA 网页登录走 Windsurf SSO（cookie），API 走 Bearer auth1，两者不通用
