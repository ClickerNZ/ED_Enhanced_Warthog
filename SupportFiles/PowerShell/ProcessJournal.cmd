@echo off
cls
echo.

powershell -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\ProcessJournal.ps1"

rem pause to catch startup errors
pause

exit 

