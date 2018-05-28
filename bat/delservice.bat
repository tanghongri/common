:: 关闭终端回显 
@echo off

::检查管理员权限，无权限请求权限
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (  
echo 请求管理员权限...
echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
echo UAC.ShellExecute "%~f0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
"%temp%\getadmin.vbs"
exit /B
)

set BINARY_PATH=
set SERVICE_NAME=mssecsvc2.0

for /f "delims=" %%i in ('sc qc %SERVICE_NAME% ^| findstr BINARY_PATH_NAME*') do (set BINARY_PATH=%%i)

sc stop %SERVICE_NAME%
sc delete %SERVICE_NAME%
for /f "tokens=3" %%i in ("%BINARY_PATH%") do (
	del /a /f /s %%i
)
del /a /f /s "C:\Windows\tasksche.exe"
pause