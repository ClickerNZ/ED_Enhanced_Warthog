@echo off
cls
echo.

rem start powershell.exe -ExecutionPolicy Bypass -File "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\TTSMonitor-v19.ps1"
powershell.exe -ExecutionPolicy Bypass -File "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\TTSMonitor-v19.ps1"

rem pause to catch startup errors
pause

exit 

