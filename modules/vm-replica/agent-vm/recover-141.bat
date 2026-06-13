@echo off
REM ============================================================
REM  vm-replica 带外恢复脚本 (Out-of-band recovery)
REM  用途：撤销多RDP/后台会话的所有持久化改动，还原到系统默认。
REM  何时用：141 重启后主账号弹"远程过程调用失败"、进不了桌面时。
REM  怎么用：
REM    1) 出错界面按 Ctrl+Shift+Esc 开任务管理器
REM    2) 文件 -> 运行新任务 -> 勾选"以系统管理权限创建" -> 浏览到本 .bat 运行
REM       (或直接输 cmd 后逐行粘贴下面命令)
REM    3) 跑完会自动重启
REM  全部可逆、不删任何文件/账号。
REM ============================================================
echo [1/4] 禁用登录自动任务 DaoVMConnector ...
schtasks /Change /TN "DaoVMConnector" /DISABLE 2>nul
echo [2/4] 禁用登录自动任务 DaoVMAgent ...
schtasks /Change /TN "DaoVMAgent" /DISABLE 2>nul
echo [3/4] 还原 TermService 为 Windows 原版 termsrv.dll (撤销 RDP Wrapper) ...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\TermService\Parameters" /v ServiceDll /t REG_EXPAND_SZ /d "%%SystemRoot%%\System32\termsrv.dll" /f
echo [4/4] 恢复单会话默认 ...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fSingleSessionPerUser /t REG_DWORD /d 1 /f
echo.
echo 完成。10 秒后重启（按 Ctrl+C 取消重启）...
timeout /t 10
shutdown /r /t 0
