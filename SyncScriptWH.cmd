@echo off

cls

echo.
echo Sync Script files with development folder
echo.

pause

del C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Output\TTSQueue\*.*
del C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Output\TTSQueue\Archive\*.*

robocopy C:\thrustmaster\ed_targetscript_warthog\ D:\Users\Den\OneDrive\Personal\Thrustmaster\TARGET\Clicker\Development\ED_Enhanced_Warthog\ /s /xf C:\thrustmaster\ed_targetscript_warthog\scriptfiles\ED_Usersettings.tmh /xd C:\thrustmaster\ed_targetscript_warthog\supportfiles\edmc /L 

rem robocopy C:\thrustmaster\ed_targetscript_warthog\scriptfiles\ D:\Users\Den\OneDrive\Personal\Thrustmaster\TARGET\Clicker\Development\ED_Enhanced_Warthog\ScriptFiles /L 
rem robocopy C:\thrustmaster\ed_targetscript_warthog\SupportFiles\ D:\Users\Den\OneDrive\Personal\Thrustmaster\TARGET\Clicker\Development\ED_Enhanced_Warthog\SupportFiles\ /s /L  

echo.
echo if output above is expected, press any key, otherwise press ctrl+c to quit
echo.

pause 

robocopy C:\thrustmaster\ed_targetscript_warthog\ D:\Users\Den\OneDrive\Personal\Thrustmaster\TARGET\Clicker\Development\ED_Enhanced_Warthog\ /s /xf C:\thrustmaster\ed_targetscript_warthog\scriptfiles\ED_Usersettings.tmh /xd C:\thrustmaster\ed_targetscript_warthog\supportfiles\edmc

pause

exit
