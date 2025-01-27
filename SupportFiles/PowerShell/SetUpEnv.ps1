# creates required environment variables for powershell to load external modules for use within the main script
# scope is temporary for current session only and would need to be run each time we run the script.
# permanent scope, create an environment variable called PSModulePath in system settings and set the path accordingly

# this project is Elite Dangerous Journal Processing to complement my ED_Enhanced_Warthog TARGET script.
$env:PSModulePath += ";C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Modules"

