@echo off

cls

echo.
echo Sync Script files with development folder?
echo.

pause

del C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Output\TTSQueue\*.*
del C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Output\TTSQueue\Archive\*.*

rem robocopy C:\thrustmaster\ed_targetscript_warthog\scriptfiles\ D:\Users\Den\OneDrive\Personal\Thrustmaster\TARGET\Clicker\Development\ED_Enhanced_Warthog\ScriptFiles /xf C:\thrustmaster\ed_targetscript_warthog\scriptfiles\ED_Usersettings.tmh /L 
rem robocopy C:\thrustmaster\ed_targetscript_warthog\SupportFiles\ D:\Users\Den\OneDrive\Personal\Thrustmaster\TARGET\Clicker\Development\ED_Enhanced_Warthog\SupportFiles\ /s /xd C:\thrustmaster\ed_targetscript_warthog\supportfiles\edmc\edmc_plugins\edmc-ClickersFolly\__pycache__ /L  

robocopy C:\thrustmaster\ed_targetscript_warthog\scriptfiles\ D:\Users\Den\OneDrive\Personal\Thrustmaster\TARGET\Clicker\Development\ED_Enhanced_Warthog\ScriptFiles /L 
robocopy C:\thrustmaster\ed_targetscript_warthog\SupportFiles\ D:\Users\Den\OneDrive\Personal\Thrustmaster\TARGET\Clicker\Development\ED_Enhanced_Warthog\SupportFiles\ /s /L  

echo.
echo if output above is expected, press any key, otherwise press ctrl+c to quit
echo.

pause 

rem robocopy C:\thrustmaster\ed_targetscript_warthog\scriptfiles\ D:\Users\Den\OneDrive\Personal\Thrustmaster\TARGET\Clicker\Development\ED_Enhanced_Warthog\ScriptFiles /xf C:\thrustmaster\ed_targetscript_warthog\scriptfiles\ED_Usersettings.tmh
rem robocopy C:\thrustmaster\ed_targetscript_warthog\SupportFiles\ D:\Users\Den\OneDrive\Personal\Thrustmaster\TARGET\Clicker\Development\ED_Enhanced_Warthog\SupportFiles\ /s /xd C:\thrustmaster\ed_targetscript_warthog\supportfiles\edmc\edmc_plugins\edmc-ClickersFolly\__pycache__

robocopy C:\thrustmaster\ed_targetscript_warthog\scriptfiles\ D:\Users\Den\OneDrive\Personal\Thrustmaster\TARGET\Clicker\Development\ED_Enhanced_Warthog\ScriptFiles
robocopy C:\thrustmaster\ed_targetscript_warthog\SupportFiles\ D:\Users\Den\OneDrive\Personal\Thrustmaster\TARGET\Clicker\Development\ED_Enhanced_Warthog\SupportFiles\ /s

pause

exit
