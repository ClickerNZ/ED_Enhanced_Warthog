@echo off
cls
echo.

start powershell -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\ProcessJournal.ps1"

rem pause to catch startup errors
rem pause

exit 

