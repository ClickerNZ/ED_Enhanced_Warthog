@echo off
echo.
echo VERSION 5.1.0 - Clicker - MASTER LAUNCHER
echo.

setlocal EnableExtensions EnableDelayedExpansion

REM === USER SETTINGS ===
set "PATH_WARTHOG=C:\Thrustmaster\ED_TargetScript_WARTHOG"
set "PATH_T16000=C:\Thrustmaster\ED_TargetScript_T16000"

REM Default if nothing matches:
set "ED_PREFIX=%PATH_WARTHOG%"

REM Set DEBUG=1 to enable debug prints
REM set "DEBUG=1"

REM === DEVICE ID CONFIG ===
REM Thrustmaster Vendor ID is 044F
set "VID=044F"

REM --- Pair 1: WARTHOG stick + throttle ---
set "PID_WH_STICK=0402"
set "PID_WH_THROTTLE=0404"

REM --- Pair 2: T16000 stick + TWCS throttle ---
set "PID_T16_STICK=B10A"
set "PID_TWCS_THROTTLE=B687"

REM --- Ignore: TFRP pedals (fill if you want extra safety; not required) ---
REM Example TFRP PID often B679/B687 depending on interface; you asked to ignore pedals anyway.
REM set "PID_TFRP=XXXX"

REM === DETECTION ===
set "CTL=UNKNOWN"

for /f "usebackq delims=" %%I in (`
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue';$vid='%VID%';$whS='%PID_WH_STICK%';$whT='%PID_WH_THROTTLE%';$t16='%PID_T16_STICK%';$twcs='%PID_TWCS_THROTTLE%';$pnp=(Get-CimInstance Win32_PnPEntity | ?{ $_.PNPDeviceID -match ('VID_'+$vid) } | select -Expand PNPDeviceID);$hasWhS=($pnp -match ('VID_'+$vid+'&PID_'+$whS));$hasWhT=($pnp -match ('VID_'+$vid+'&PID_'+$whT));$hasT16=($pnp -match ('VID_'+$vid+'&PID_'+$t16));$hasTwcs=($pnp -match ('VID_'+$vid+'&PID_'+$twcs));if($env:DEBUG -eq '1'){Write-Output ('DBG:PnPCount=' + ($pnp|Measure-Object).Count);Write-Output ('DBG:WH_STICK=' + $hasWhS + ' WH_THROTTLE=' + $hasWhT + ' T16_STICK=' + $hasT16 + ' TWCS_THROTTLE=' + $hasTwcs);}if($hasWhS -and $hasWhT){'WARTHOG'}elseif($hasT16 -and $hasTwcs){'T16000_TWCS'}else{'UNKNOWN'}"
`) do (
  set "line=%%I"
  REM Capture first non-debug result as CTL; print debug lines only when DEBUG=1
  if /i "%DEBUG%"=="1" (
    if "!line:~0,4!"=="DBG:" echo !line!
  )
  if not "!line:~0,4!"=="DBG:" (
    set "CTL=!line!"
  )
)

REM === APPLY PREFERENCE (WARTHOG wins because PS checks it first) ===
if /i "%CTL%"=="WARTHOG" (
  set "ED_PREFIX=%PATH_WARTHOG%"
) else if /i "%CTL%"=="T16000_TWCS" (
  set "ED_PREFIX=%PATH_T16000%"
) else (
  if /i "%DEBUG%"=="1" echo DBG:No known controller pair detected; using default.
)

if /i "%DEBUG%"=="1" (
  echo DBG:CTL=%CTL%
  echo DBG:ED_PREFIX=%ED_PREFIX%
)
echo CTL=%CTL%
echo Using: %ED_PREFIX%

rem pause

echo.
rem		Ensure destination username and destination folder is correct...
echo Copy correct controller bindfiles...

xcopy %ED_PREFIX%\bindfiles\*.binds "c:\users\den\appdata\local\frontier developments\elite dangerous\options\bindings\" /d /f /y /i 
xcopy %ED_PREFIX%\bindfiles\*.start "c:\users\den\appdata\local\frontier developments\elite dangerous\options\bindings\" /f /y /i

echo.

rem pause

echo Start Clicker's EDLauncher...
d:
cd "\Program Files (x86)\Frontier\EDLaunch"
start EDLaunch-Clicker.exe

rem timeout /t 5

echo Starting supporting apps...
echo.
echo Start EDMC...
c:
cd "\Program Files (x86)\EDMarketConnector\"
start EDMarketConnector.exe
echo.

rem timeout /t 5

echo Start SrvSurvey...
c:
cd "\Program Files (x86)\SrvSurvey"
start SrvSurvey.exe
echo.

rem echo Start EDTrackerPro...
rem c:
rem cd "\Program Files (x86)\EDTracker LTD\EDTracker Pro UI\"
rem start EDTrackerPro.exe
rem echo.

rem timeout /t 5

rem echo Start Opentrack...
rem c:
rem cd "\Program Files (x86)\opentrack\"
rem start opentrack.exe
rem echo.

rem timeout /t 5

rem echo Start Voice Attack...
rem cd "\Program Files (x86)\VoiceAttack\"
rem start VoiceAttack.exe -shortcutson

rem timeout /t 5

rem echo Start TeamSpeak...
rem cd "\Users\<username>\AppData\Local\TeamSpeak 3 Client"
rem start ts3client_win64.exe

rem timeout /t 5

rem echo Check to see if VoiceAttack is running and set variable accordingly...
rem tasklist /FI "IMAGENAME eq voiceattack.exe" 2>NUL | find /I /N "voiceattack.exe">NUL
rem if "%ERRORLEVEL%"=="0" (echo 1 > c:\vastatus.txt) else (echo 0 > c:\vastatus.txt)

echo.
echo Start TARGET script...
c:
cd "\program files (x86)\thrustmaster\target\x64\"
start targetgui.exe -r "%ED_PREFIX%\ScriptFiles\ed_enhanced_main.tmc"
echo.

timeout /t 5 /nobreak >nul
rem pause
echo. 
echo Start TTSMonitor powershell script...
start powershell -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "%ED_PREFIX%\SupportFiles\PowerShell\TTSMonitor.ps1"
echo.


timeout /t 20 /nobreak >nul

rem DO THIS LAST

echo Start ProcessJournal powershell script...
start powershell -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "%ED_PREFIX%\SupportFiles\PowerShell\ProcessJournal.ps1"
// start powershell -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "%ED_PREFIX%\SupportFiles\PowerShell\ProcessJournal-v34.ps1"
echo.

rem timeout /t 5

rem echo Start Opentrack...
rem c:
rem cd "\Program Files (x86)\opentrack\"
rem start opentrack.exe
rem echo.

timeout /t 10

endlocal

exit
