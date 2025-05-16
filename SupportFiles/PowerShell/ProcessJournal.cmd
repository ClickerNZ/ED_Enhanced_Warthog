@echo off
cls
echo.

rem start powershell -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\ProcessJournal-v29.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\ProcessJournal-v29.ps1"

rem pause to catch startup errors
pause

exit 

