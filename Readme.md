CMDR Clicker's Thrustmaster TARGET Script for Elite Dangerous  
  
Version 510 (Trailblazers)  
  
STATUS: BETA (Development phase)  
  
Requires latest version of TARGET software + a Thrustmaster WARTHOG Joystick and Throttle.  
(Rudder Pedals are optional but highly recommended)  
  
Whilst it works as is, this package is currently being developed and may contain bugs and half finished functions.  
I will create a more comprehensive and up to date documentation set when I come to publish the script as a  finished project (or near as dammit finished)  
  
If you want to test fly this script...  
1. Download the zip package  
2. Unzip to C:\Thrustmaster\ED_TargetScript_Warthog\ (create folders if needed)  
3. Copy the bind files from C:\Thrustmaster\ED_TargetScript_Warthog\BindFiles folder into the Elite Dangerous bind file location   
   Usually found at C:\Users\<windows username>\AppData\Local\Frontier Developments\Elite Dangerous\Options\Bindings  
4. Open C:\Thrustmaster\ED_TargetScript_Warthog\ScriptFiles\ED_UserSettings.tmh via notepad++ and carefully go through and set your preferences  
   a. Ensure that the path to the status.json file is correct  
      Usually found at C:\Users\<windows user name>\Saved Games\Frontier Developments\Elite Dangerous  
5. Run the 2x batch files under C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\powershell folder  
   a. PSJournal.cmd  
   b. TTSMonitor.cmd  
   These rely on paths to journal file to be correct within the script  
   Open the corresponding .ps1 files via notepad++ and adjust if necessary  
6. Open C:\Thrustmaster\ED_TargetScript_Warthog\ScriptFiles\ED_Enhanced_Warthog.tmc via TARGET Script Editor, compile then run  
7. Run Elite Dangerous  
8. Set the Controller Options for General, Ship and SRV to point to the bind file copied during step 3  
9. Set the Controller Options for On Foot to the custom bind file  
  
Fly Dangerous Commanders ... o7  
  
CMDR Clicker  
