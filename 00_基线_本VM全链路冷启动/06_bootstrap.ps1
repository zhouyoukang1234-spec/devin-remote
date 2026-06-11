# 00 · 一键冷启动 bootstrap.ps1 —— 新 agent 在新 VM 上从零到可开工
# 用法: 把 00_基线 整个文件夹拷到 VM（或经 dao-bridge 拉取），然后:
#   powershell -ExecutionPolicy Bypass -File .\06_bootstrap.ps1
# 道法自然，无为而无不为。

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$art  = Join-Path $here 'artifacts'

Write-Host '=== [1/5] 环境检查 ==='
foreach ($t in 'node','npm','git','python') {
  $c = Get-Command $t -ErrorAction SilentlyContinue
  if ($c) { Write-Host "  $t : OK ($($c.Source))" } else { Write-Host "  $t : 缺失 — 请安装（node>=18 / git / python3）" -ForegroundColor Yellow }
}

Write-Host '=== [2/5] IDE 检查（Windsurf 或 Devin Desktop，二选一即可） ==='
$ws = Get-Command windsurf -ErrorAction SilentlyContinue
$dd = Get-Command devin-desktop -ErrorAction SilentlyContinue
if (-not $ws -and -not $dd) {
  Write-Host '  两者都未安装。下载安装其一:' -ForegroundColor Yellow
  Write-Host '    Windsurf:      https://windsurf.com/download'
  Write-Host '    Devin Desktop: https://windsurf.com/devin （装到 %LOCALAPPDATA%\Programs\Devin，CLI: devin-desktop）'
  Write-Host '  安装后重新运行本脚本。'
  exit 1
}
$cli = if ($ws) { 'windsurf' } else { 'devin-desktop' }
Write-Host "  使用 CLI: $cli"

Write-Host '=== [3/5] 安装四插件 + 切号插件（artifacts 直装，免构建） ==='
$vsixList = @(
  'dao-proxy-pro-9.9.261.vsix',   # 插件① 代理/Provider 路由（主线基础）
  'dao-vsix-1.0.3.vsix',          # 插件② Devin Cloud 面板（auth1 登录链）
  'devin-git-auth-2.0.0.vsix',    # 插件④ 多 Devin 账号→一个 GitHub
  'rt-flow-3.16.0.vsix'           # 切号插件（基准版 3.16.0）
)
foreach ($v in $vsixList) {
  $p = Join-Path $art $v
  if (Test-Path $p) { & $cli --install-extension $p --force; Write-Host "  installed: $v" }
  else { Write-Host "  缺文件: $v （到 141 E:\DAO_ARCHIVE\00_基线\artifacts 取）" -ForegroundColor Yellow }
}

Write-Host '=== [4/5] 登录与账号 ==='
Write-Host '  主账号: lcld26815946@gmail.com （密码见 04_交接 / 05_补充 文档）'
Write-Host '  登录方式: 打开 IDE → 登录页 https://windsurf.com/devin/account/login 取 ott$ 令牌'
Write-Host '  多账号切号: rt-flow 插件 + %USERPROFILE%\.wam\accounts.md（7 账号，141 上有副本）'

Write-Host '=== [5/5] 验证 ==='
& $cli --list-extensions --show-versions | Select-String -Pattern 'dao|rt-flow|devin'
Write-Host '通道体检: python tools\verify_channel.py （dao-bridge → 141）'
Write-Host '完成。下一步读 05_补充_e0405e88成果整合.md 的统一待办清单。'
