@echo off

echo.
echo VERSION 5.1.0
echo.

rem pause

echo Start EDLauncher...
d:
cd "\Program Files (x86)\Frontier\EDLaunch"
start EDLaunch-2Dogs.exe

rem timeout /t 5

echo Starting supporting apps...
echo.
echo Start EDMC...
c:
cd "\Program Files (x86)\EDMarketConnector\"
start EDMarketConnector.exe
echo.

rem timeout /t 5

rem echo Start Opentrack...
rem c:
rem cd "\Program Files (x86)\opentrack\"
rem start opentrack.exe
rem echo.

rem timeout /t 5

echo.
echo Start TARGET script...
c:
cd "\program files (x86)\thrustmaster\target\x64\"
rem start targetgui.exe -r "c:\Thrustmaster\ED_TargetScript\script\ed_main.tmc"
start targetgui.exe -r "C:\Thrustmaster\ED_TargetScript_Warthog\ScriptFiles\ed_enhanced_warthog.tmc"
echo.

timeout /t 5 /nobreak >nul
rem pause
echo. 
echo Start TTSMonitor powershell script...
start powershell -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\TTSMonitor.ps1"
echo.

timeout /t 17 /nobreak >nul

rem DO THIS LAST

echo Start ProcessJournal powershell script...
start powershell -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\ProcessJournal.ps1"
echo.

exit
