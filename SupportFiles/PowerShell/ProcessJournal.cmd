@echo off

powershell -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\ProcessJournal-v17.ps1"

echo ProcessJournal script has exited.
rem pause to catch startup errors
rem pause

exit 

