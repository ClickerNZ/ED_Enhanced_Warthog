@echo off
cls
echo.

powershell.exe -ExecutionPolicy Bypass -File "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\TTSMonitor.ps1"

rem pause to catch startup errors
rem pause

exit 

