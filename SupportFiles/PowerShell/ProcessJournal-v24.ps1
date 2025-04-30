# v24	- Position console window - not working so have removed the code.

param (
    [string]$inputFolderPath = "D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous",			# Input folder containing the Journal*.log files
    [string]$outputFolderPath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Output",				# Output folder to save the text files
    [string]$trackingFilePath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Output\Tracking.txt"	# File to track the last processed timestamp
)

$JsonFilePath = Join-Path -Path $outputFolderPath -ChildPath "MyJournalData.json"

# Set the module path for the current session
$customModulePath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Modules"
if (-Not ($env:PSModulePath -like "*$customModulePath*")) {
    $env:PSModulePath += ";$customModulePath"
}

# Import our modules...

Import-Module TransformUtilities
# Verify the module is loaded
if (-Not (Get-Module -Name TransformUtilities)) {
    throw "Failed to import the MapUtilities module. Ensure the module exists in $customModulePath."
}

Import-Module TTS
# Verify the module is loaded
if (-Not (Get-Module -Name TTS)) {
    throw "Failed to import the TTS module. Ensure the module exists in $customModulePath."
}
	# USAGE: [TTS]::SpeakText(text, voice, rate, volume)
	# voice, rate and volume are optional ... refer TTS.psm1 for default settings

$voice = "Microsoft Catherine"
$rate = 0
$volume = 75

[TTS]::SpeakText("Journal processor version 24 loading", $voice, $rate, $volume)


#Set the window title 
try {
    $host.UI.RawUI.WindowTitle = "Process Journal v24"
} catch {
    Write-Host "Could not set window title: $_"
}

# Load the map file into memory
Import-MapFile -FilePath "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Lookup\EDData.json"
	# USAGE:
	# $shipvalue = Get-MappedValue -MapName "ShipType_map" -Key "diamondbackxl"
	# Write-Output "The value for the key is: $shipvalue"
	# USAGE:
	# $exovalue = Get-MappedValue -MapName "Exobiology_Value_map" -Key "Aleoida Arcus"
	# $formattedNum = $exovalue.ToString("N0")
	# Write-Output "The value for the key is: $formattedNum"

Write-Host "ProcessJournal v24"

# Ensure the output folder exists
if (-not (Test-Path -Path $outputFolderPath)) {
    New-Item -Path $outputFolderPath -ItemType Directory
}

# Ensure the tracking file exists
if (-not (Test-Path -Path $trackingFilePath)) {
    Set-Content -Path $trackingFilePath -Value "{\"lastTimestamp\":null}" -Encoding ascii
}

# Initialize or Load Global Variables from JSON
function Initialize-GlobalVariables {
    if (-Not (Test-Path $JsonFilePath)) {
        # JSON file does not exist, create it with default values
        $defaultData = @{
            CMDRName		= "not set"
            ShipName		= "not set"
            ShipType		= "not set"
            StationName		= "not set"
            StationType		= "not set"
            SystemName		= "not set"
            BodyName		= "not set"
            OrganicFound	= "not set"
			DockingStatus	= "not set"
			DeniedReason	= "not set"
			LandingPad		= "not set"
			ActiveFighter	= "FALSE"
        }
        $defaultData | ConvertTo-Json | Set-Content $JsonFilePath
    }

    # Read JSON file and parse data
    $jsonData = Get-Content $JsonFilePath | ConvertFrom-Json

    # Assign global variables
    $Global:CMDRName = $jsonData.CMDRName
    $Global:ShipName = $jsonData.ShipName
    $Global:ShipType = $jsonData.ShipType
    $Global:StationName = $jsonData.StationName
    $Global:StationType = $jsonData.StationType
    $Global:SystemName = $jsonData.SystemName
    $Global:BodyName = $jsonData.BodyName
    $Global:OrganicFound = $jsonData.OrganicFound	
	$Global:DockingStatus = $jsonData.DockingStatus
	$Global:DeniedReason = $jsonData.DeniedReason
	$Global:LandingPad = $jsonData.LandingPad
	$Global:ActiveFighter = $jsonData.ActiveFighter
	
}

# Compare newKeyValues with Global KeyValues
function Compare-And-UpdateVariables {
    $changeDetected = $false

    # List of tracked keys
    $keys = @("CMDRName", "ShipName", "ShipType", "StationName", "StationType", "SystemName", "BodyName", "OrganicFound", "DockingStatus", "DeniedReason", "LandingPad", "ActiveFighter")

    foreach ($key in $keys) {
        $globalKeyName = "Global:$key"
        $newKeyName = "Global:new$key"

        if (Test-Path Variable:$newKeyName) {
            if ((Get-Variable -Name "new$key" -Scope Global).Value -ne (Get-Variable -Name $key -Scope Global).Value) {
                $changeDetected = $true
                break					# if we detect a change, no point testing any more keys
            }
        }
    }

	$localtime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"  # Match log file timestamp format

    if ($changeDetected) {
        foreach ($key in $keys) {
            $newKeyName = "Global:new$key"
            $globalKeyName = "Global:$key"

            if (Test-Path Variable:$newKeyName) {
                Set-Variable -Name $key -Value (Get-Variable -Name "new$key" -Scope Global).Value -Scope Global
            }
        }
        Update-JsonFile
		Write-Host "[$localtime] : Updated MyJournalData.json" -ForegroundColor Cyan
    }
	else {
		#Write-Host "[$localtime] : MyJournalData.json NOT Updated" -ForegroundColor Blue
	}
}

# Update JSON File
function Update-JsonFile {
	
	$Global:localtime = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
	
    $updatedData = [ordered]@{
        localtime		= $Global:localtime
        CMDRName		= $Global:CMDRName
        ShipName		= $Global:ShipName
        ShipType		= $Global:ShipType
        StationName		= $Global:StationName
        StationType		= $Global:StationType
        SystemName		= $Global:SystemName
        BodyName		= $Global:BodyName
        OrganicFound	= $Global:OrganicFound
		DockingStatus	= $Global:DockingStatus
		DeniedReason	= $Global:DeniedReason 
		LandingPad		= $Global:LandingPad
		ActiveFighter	= $Global:ActiveFighter
    }

    $updatedData | ConvertTo-Json -Compress | Set-Content $JsonFilePath
 }

# Read the timestamped tracking file
function Get-LastTimestamp {
    try {
        $trackingData = Get-Content -Path $trackingFilePath | ConvertFrom-Json
        return $trackingData.lastTimestamp
    } catch {
        Write-Host "Error reading tracking file: $_" -ForegroundColor Red
        return $null
    }
}

# Update the timestamp tracking file
function Update-LastTimestamp {
    param (
        [string]$newTimestamp
    )
    try {
        $trackingData = @{ lastTimestamp = $newTimestamp }
        $trackingData | ConvertTo-Json | Set-Content -Path $trackingFilePath -Encoding ascii
    } catch {
        Write-Host "Error updating tracking file: $_" -ForegroundColor Red
    }
}

# Process Journal log file
function Process-LogFile {
    param (
        [string]$filePath,
        [string]$lastTimestamp
    )
		
    #Write-Host "Processing log file: $filePath starting from timestamp: $lastTimestamp" -ForegroundColor Yellow

    $localtime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"  # Match log file timestamp format

    try {
        $entries = Get-Content -Path $filePath | ForEach-Object { $_ | ConvertFrom-Json }
        $updatedTimestamp = $lastTimestamp

        foreach ($entry in $entries) {
            if ($null -eq $lastTimestamp -or $entry.timestamp -gt $lastTimestamp) {
                #Write-Host "Processing entry with timestamp: $($entry.timestamp)"

                switch ($entry.event) {					
                    "Commander" {
                        if ("Name" -in $entry.PSObject.Properties.Name) {
							$Global:newCMDRName = $entry.Name
							if ($Global:Debug) {
								if (-not $Global:GameRunning) {
									Write-Host "[$updatedTimestamp] : Event: Commander, Name = $Global:newCMDRName" -ForegroundColor Yellow 
								}
								else {
									Write-Host "[$updatedTimestamp] : Event: Commander, Name = $Global:newCMDRName" -ForegroundColor Cyan
								}
							}
                        }
                    }
                    "LoadGame" {
                        if ("Ship" -in $entry.PSObject.Properties.Name) {
 							$ShipType = Get-MappedValue -MapName "ShipType_map" -Key $entry.ship
							$Global:newShipType = $ShipType
							if ($Global:Debug) {
								if (-not $Global:GameRunning) {
									Write-Host "[$updatedTimestamp] : Event: LoadGame, Ship = $Global:newShipType" -ForegroundColor Yellow 
								}
								else {
									Write-Host "[$updatedTimestamp] : Event: LoadGame, Ship = $Global:newShipType" -ForegroundColor Cyan 
								}
							}
                        }
                    }					
                    "Docked" {
                        if ("StationName" -in $entry.PSObject.Properties.Name) {
							$Global:newStationName = $entry.StationName
							$Global:newDockingStatus = "Docked"
							$Global:newDeniedReason = "not denied"
							if ($Global:Debug) {
								if (-not $Global:GameRunning) {
									Write-Host "[$updatedTimestamp] : Event: Docked, StationName = $Global:newStationName" -ForegroundColor Yellow 
									Write-Host "[$updatedTimestamp] : Event: Docked, DockingStatus = $Global:newDockingStatus" -ForegroundColor Yellow 
									Write-Host "[$updatedTimestamp] : Event: Docked, DeniedReason = $Global:newDeniedReason" -ForegroundColor Yellow 
									Write-Host "[$updatedTimestamp] : Event: Docked, LandingPad = $Global:newLandingPad" -ForegroundColor Yellow 
								}
								else {
									Write-Host "[$updatedTimestamp] : Event: Docked, StationName = $Global:newStationName" -ForegroundColor Cyan 
									Write-Host "[$updatedTimestamp] : Event: Docked, LandingPad = $Global:newLandingPad" -ForegroundColor Cyan 
								}
							}							
                        }
                        if ("StationType" -in $entry.PSObject.Properties.Name) {
							$Global:newStationType = $entry.StationType
							if ($Global:Debug) {
								if (-not $Global:GameRunning) {
									Write-Host "[$updatedTimestamp] : Event: Docked, StationType = $Global:newStationType" -ForegroundColor Yellow 
								}
								else {
									Write-Host "[$updatedTimestamp] : Event: Docked, StationType = $Global:newStationType" -ForegroundColor Cyan
								}
							}							
                        }
                    }
                    "ShipyardSwap" {
                        if ("ShipType" -in $entry.PSObject.Properties.Name) {
							$ShipType = Get-MappedValue -MapName "ShipType_map" -Key $entry.shiptype
							$Global:newShipType = $ShipType
							if ($Global:Debug) {
								if (-not $Global:GameRunning) {
									Write-Host "[$updatedTimestamp] : Event: ShipyardSwap, ShipType = $Global:newShipType" -ForegroundColor Yellow 
								}
								else {
									Write-Host "[$updatedTimestamp] : Event: ShipyardSwap, ShipType = $Global:newShipType" -ForegroundColor Cyan 
								}
							}
                        }
                    }
                    "Loadout" {
                        if ("Ship" -in $entry.PSObject.Properties.Name) {
							$ShipType = Get-MappedValue -MapName "ShipType_map" -Key $entry.ship
							$Global:newShipType = $ShipType
							if ($Global:Debug) {
								if (-not $Global:GameRunning) {
									Write-Host "[$updatedTimestamp] : Event: Loadout, Ship = $Global:newShipType" -ForegroundColor Yellow 
								}
								else {
									Write-Host "[$updatedTimestamp] : Event: Loadout, Ship = $Global:newShipType" -ForegroundColor Cyan									
								}
							}														
                        }
                        if ("ShipName" -in $entry.PSObject.Properties.Name) {
							$Global:newShipName = $entry.ShipName
							if ($Global:Debug) {
								if (-not $Global:GameRunning) {
									Write-Host "[$updatedTimestamp] : Event: Loadout, ShipName = $Global:newShipName" -ForegroundColor Yellow 
								}
								else {
									Write-Host "[$updatedTimestamp] : Event: Loadout, ShipName = $Global:newShipName" -ForegroundColor Cyan
								}
							}														
                        }
						if ($Global:GameRunning) {
							$voice = "Microsoft Catherine"
							$rate = 0
							$volume = 75
						}
                    }
                    "Location" {
                        if ("StarSystem" -in $entry.PSObject.Properties.Name) {
							$Global:newSystemName = $entry.StarSystem
							if ($Global:Debug) {
								if (-not $Global:GameRunning) {
									Write-Host "[$updatedTimestamp] : Event: Location, StarSystem = $Global:newSystemName" -ForegroundColor Yellow 
								}
								else {
									Write-Host "[$updatedTimestamp] : Event: Location, StarSystem = $Global:newSystemName" -ForegroundColor Cyan
								}
							}																					
                        }
                        if ("Body" -in $entry.PSObject.Properties.Name) {
							$Global:newBodyName = $entry.Body
							if ($Global:Debug) {
								if (-not $Global:GameRunning) {
									Write-Host "[$updatedTimestamp] : Event: Location, Body = $Global:newBodyName" -ForegroundColor Yellow 
								}
								else {
									Write-Host "[$updatedTimestamp] : Event: Location, Body = $Global:newBodyName" -ForegroundColor Cyan
								}
							}																					
                        }
                        if ("StationName" -in $entry.PSObject.Properties.Name) {
							$Global:newStationName = $entry.StationName
							if ($Global:Debug) {
								if (-not $Global:GameRunning) {
									Write-Host "[$updatedTimestamp] : Event: Location, StationName = $Global:newStationName" -ForegroundColor Yellow 
								}
								else {
									Write-Host "[$updatedTimestamp] : Event: Location, StationName = $Global:newStationName" -ForegroundColor Cyan
								}
							}																					
                        }
                        if ("StationType" -in $entry.PSObject.Properties.Name) {
							$Global:newStationType = $entry.StationType
							if ($Global:Debug) {
								if (-not $Global:GameRunning) {
									Write-Host "[$updatedTimestamp] : Event: Location, StationType = $Global:newStationType" -ForegroundColor Yellow 
								}
								else {
									Write-Host "[$updatedTimestamp] : Event: Location, StationType = $Global:newStationType" -ForegroundColor Cyan
								}
							}																					
                        }
                    }
                    "Touchdown" {
                        if ("Body" -in $entry.PSObject.Properties.Name) {
							$Global:newBodyName = $entry.Body
							if ($Global:Debug) {
								if (-not $Global:GameRunning) {
									Write-Host "[$updatedTimestamp] : Event: TouchDown, Body = $Global:newBodyName" -ForegroundColor Yellow 
								}
								else {
									Write-Host "[$updatedTimestamp] : Event: TouchDown, Body = $Global:newBodyName" -ForegroundColor Cyan
								}
							}																					
                        }
                    }
					"DockingCancelled" {
						#if ($Global:RequestStation -eq $entry.StationName) {
							$Global:RequestStation = $entry.StationName
							$Global:newDockingStatus = "Cancelled"
							$Global:newLandingPad = "not set"
							$Global:newDeniedReason = "not set"
						#}
						if ($Global:Debug) {
							if (-not $Global:GameRunning) {
								Write-Host "[$updatedTimestamp] : Event: DockingCancelled, StationName = $Global:RequestStation" -ForegroundColor Yellow 
							}
							else {
								Write-Host "[$updatedTimestamp] : Event: DockingCancelled, StationName = $Global:RequestStation" -ForegroundColor Cyan 
							}
						}																											
					}
					"DockingDenied" {
						#if ($Global:RequestStation -eq $entry.StationName) {
							$Global:RequestStation = $entry.StationName # [DM] added this same time as comment out the 'if' statement
							$Global:newDockingStatus = "Denied"
							$Global:newDeniedReason = $entry.Reason
							$Global:newLandingPad = "not set"
						#}
						if ($Global:Debug) {
							if (-not $Global:GameRunning) {
								#Write-Host "[$updatedTimestamp] : Event: DockingDenied, StationName = $Global:RequestStation" -ForegroundColor Yellow 
								Write-Host "[$updatedTimestamp] : Event: DockingDenied, Reason = $Global:newDeniedReason" -ForegroundColor Yellow 
							}
							else {
								#Write-Host "[$updatedTimestamp] : Event: DockingDenied, StationName = $Global:RequestStation" -ForegroundColor Cyan 
								Write-Host "[$updatedTimestamp] : Event: DockingDenied, Reason = $Global:newDeniedReason" -ForegroundColor Cyan 
							}
						}																																	
					}
					"DockingTimeout" {
						#if ($Global:RequestStation -eq $entry.StationName) {
							$Global:RequestStation = $entry.StationName
							$Global:newDockingStatus = "Timeout"
							$Global:newDeniedReason = "not set"
							$Global:newLandingPad = "not set"
						#}
						if ($Global:Debug) {
							if (-not $Global:GameRunning) {
								Write-Host "[$updatedTimestamp] : Event: DockingTimeout, StationName = $Global:RequestStation" -ForegroundColor Yellow 
							}
							else {
								Write-Host "[$updatedTimestamp] : Event: DockingTimeout, StationName = $Global:RequestStation" -ForegroundColor Cyan 
							}
						}																																	
					}					
					"DockingGranted" {
						#if ($Global:RequestStation -eq $entry.StationName) {
							$Global:newDockingStatus = "Granted"
							$Global:newLandingPad = $entry.LandingPad
							$Global:newStationName = $entry.StationName
							$Global:newDeniedReason = "not denied"
						#}
						$Global:StationType = $entry.StationType
						if ($Global:Debug) {
							if (-not $Global:GameRunning) {
								Write-Host "[$updatedTimestamp] : Event: DockingGranted, StationName = $Global:newStationName" -ForegroundColor Yellow 
								Write-Host "[$updatedTimestamp] : Event: DockingGranted, LandingPad = $Global:newLandingPad" -ForegroundColor Yellow 
							}
							else {
								Write-Host "[$updatedTimestamp] : Event: DockingGranted, StationName = $Global:newStationName" -ForegroundColor Cyan  
								Write-Host "[$updatedTimestamp] : Event: DockingGranted, LandingPad = $Global:newLandingPad" -ForegroundColor Cyan 
							}
						}
					}
#					"DockingRequested" {
#						$Global:RequestStation = $entry.StationName
#						$Global:newDockingStatus = "Requested"
#						if ($Global:Debug) {
#							if (-not $Global:GameRunning) {
#								Write-Host "[$updatedTimestamp] : Event: DockingRequested, StationName = $Global:RequestStation" -ForegroundColor Yellow 
#							}
#							else {
#								Write-Host "[$updatedTimestamp] : Event: DockingRequested, StationName = $Global:RequestStation" -ForegroundColor Cyan 
#							}
#						}																											
#					}
					"Undocked" {
						$Global:RequestStation = $entry.StationName
						$Global:newDockingStatus = "Undocked"
						$Global:newDeniedReason = "not set"
						$Global:newLandingPad = "not set"
						$Global:newStationName = "not set"
						$Global:newStationType = "not set"
						if ($Global:Debug) {
							if (-not $Global:GameRunning) {
								Write-Host "[$updatedTimestamp] : Event: Undocked, StationName = $Global:RequestStation" -ForegroundColor Yellow 
							}
							else {
								Write-Host "[$updatedTimestamp] : Event: Undocked, StationName = $Global:RequestStation" -ForegroundColor Cyan 
							}
						}																											
					}					
                    "FSDJump" {
                        if ("StarSystem" -in $entry.PSObject.Properties.Name) {
							$Global:newSystemName = $entry.StarSystem
							if ($Global:Debug) {
								if (-not $Global:GameRunning) {
									Write-Host "[$updatedTimestamp] : Event: FSDJump, StarSystem = $Global:newSystemName" -ForegroundColor Yellow 
								}
								else {
									Write-Host "[$updatedTimestamp] : Event: FSDJump, StarSystem = $Global:newSystemName" -ForegroundColor Cyan
								}
							}																					
                        }
                    }
                    "ScanOrganic" {						
                        if (("ScanType" -in $entry.PSObject.Properties.Name) -and $entry.ScanType -eq "Analyse" -and ("Species_Localised" -in $entry.PSObject.Properties.Name)) {
							if ($Global:GameRunning) { 								
								$exovalue = Get-MappedValue -MapName "Exobiology_Value_map" -Key $entry.Species_Localised
								$formattedNum = [math]::Round($exovalue / 1000000, 1)
								$Global:newOrganicFound = $entry.Species_Localised
								[TTS]::SpeakText("Value of $Global:newOrganicFound is $formattedNum million")
							}
							if ($Global:Debug) {
								if (-not $Global:GameRunning) {
									Write-Host "[$updatedTimestamp] : Event: ScanOrganic, Species_Localised = $Global:newOrganicFound" -ForegroundColor Yellow 
								}
								else {
									Write-Host "[$updatedTimestamp] : Event: ScanOrganic, Species_Localised = $Global:newOrganicFound" -ForegroundColor Cyan  
								}
							}																					
                        }
                    }
					"LaunchFighter" {
						$Global:newActiveFighter = "TRUE"
						if ($Global:Debug) {
							if (-not $Global:GameRunning) {
								Write-Host "[$updatedTimestamp] : Event: LaunchFighter, ActiveFighter = $Global:newActiveFighter" -ForegroundColor Yellow 
							}
							else {
								Write-Host "[$updatedTimestamp] : Event: LaunchFighter, ActiveFighter = $Global:newActiveFighter" -ForegroundColor Cyan
							}
						}																											
					}
					"FighterDestroyed" {
						$Global:newActiveFighter = "FALSE"
						if ($Global:Debug) {
							if (-not $Global:GameRunning) {
								Write-Host "[$updatedTimestamp] : Event: FighterDestroyed, ActiveFighter = $Global:newActiveFighter" -ForegroundColor Yellow 
							}
							else {
								Write-Host "[$updatedTimestamp] : Event: FighterDestroyed, ActiveFighter = $Global:newActiveFighter" -ForegroundColor Cyan
							}
						}																											
					}
					"DockFighter" {
						$Global:newActiveFighter = "FALSE"
						if ($Global:Debug) {
							if (-not $Global:GameRunning) {
								Write-Host "[$updatedTimestamp] : Event: DockFighter, ActiveFighter = $Global:newActiveFighter" -ForegroundColor Yellow 
							}
							else {
								Write-Host "[$updatedTimestamp] : Event: DockFighter, ActiveFighter = $Global:newActiveFighter" -ForegroundColor Cyan
							}
						}																											
					}
					"Shutdown" {
						$localtime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
						Write-Host "[$localtime] Shutdown event encountered: Game Running is $Global:GameRunning" -ForegroundColor Yellow -BackgroundColor Green                        
						if ($Global:GameRunning -and $null -ne $watcher1) {
							try {
								$watcher1.Dispose()
								Write-Host "[$localtime] Watcher1 disposed." -ForegroundColor Green
							} catch {
								Write-Host "[$localtime] Error disposing watcher: $_" -ForegroundColor Red
							}
							Write-Host "[$localtime] Exiting script in 20 seconds..." -ForegroundColor Cyan
							Start-Sleep -Milliseconds 20000
							Stop-Process -Id $PID -Force  # Forcefully kill script
						}
					}
                }
                $updatedTimestamp = $entry.timestamp
            }
        }
        Update-LastTimestamp -newTimestamp $updatedTimestamp
		
		Compare-And-UpdateVariables			# Compares Global:newKeyValues with Global:KeyValues and updates MyJournalData.json
		
    } catch {
        Write-Host "Error processing log file: $_" -ForegroundColor Red
    }
}

# Get the newest journal log
function Get-NewestLogFile {
    try {
        $logFiles = Get-ChildItem -Path $inputFolderPath -Filter "Journal*.log" | Sort-Object LastWriteTime -Descending
        return $logFiles[0]
    } catch {
        Write-Host "Error retrieving newest log file: $_" -ForegroundColor Red
        return $null
    }
}

# Process the newest log file on startup
function Process-NewestLogFile {
    $newestFile = Get-NewestLogFile
    if ($null -ne $newestFile) {
        try {
            $entries = Get-Content -Path $newestFile.FullName | ForEach-Object { $_ | ConvertFrom-Json }
            if ($entries.Count -gt 0 -and $entries[0].timestamp) {
                Update-LastTimestamp -newTimestamp $entries[0].timestamp
            }
            Process-LogFile -filePath $newestFile.FullName -lastTimestamp $entries[0].timestamp
        } catch {
            Write-Host "Error processing newest log file: $_" -ForegroundColor Red
        }
    }
}

#####################
# Main script logic #
#####################

#Define Global variables 
$Global:GameRunning = $false
$Global:DEBUG = $true 

#Initialize-GlobalVariables by reading MyJournalData.json 
Initialize-GlobalVariables

# Start glogal vars matching each other then let's go from there...
$Global:newCMDRName = $Global:CMDRName 
$Global:newShipName = $Global:ShipName 
$Global:newShipType = $Global:ShipType 
$Global:newStationName = $Global:StationName 
$Global:newStationType = $Global:StationType 
$Global:newSystemName = $Global:SystemName 
$Global:newBodyName = $Global:BodyName 
$Global:newOrganicFound = $Global:OrganicFound
$Global:newDockingStatus = $Global:DockingStatus 
$Global:newDeniedReason = $Global:DeniedReason 
$Global:newLandingPad = $Global:LandingPad
$Global:newActiveFighter = $Global:ActiveFighter

$Global:RequestStation = ""

Process-NewestLogFile

# FileSystemWatcher for real-time monitoring
$watcher1 = New-Object System.IO.FileSystemWatcher
$watcher1.Path = $inputFolderPath
$watcher1.Filter = "Journal*.log"
$watcher1.EnableRaisingEvents = $true
$watcher1.IncludeSubdirectories = $false

Register-ObjectEvent -InputObject $watcher1 -EventName "Changed" -Action {
    param($sender, $eventArgs)
	$Global:GameRunning = $true 
    $newestFile = Get-NewestLogFile
	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	#Write-Host "[$timestamp] - Journal file changed, call Process-Logfile"
    if ($eventArgs.FullPath -eq $newestFile.FullName) {
        $lastTimestamp = Get-LastTimestamp
        Process-LogFile -filePath $newestFile.FullName -lastTimestamp $lastTimestamp
    }
}

Register-ObjectEvent -InputObject $watcher1 -EventName "Created" -Action {
    param($sender, $eventArgs)
    Write-Host "Detected new file: $($eventArgs.FullPath)" -ForegroundColor Yellow 
    $newestFile = Get-NewestLogFile
    if ($eventArgs.FullPath -eq $newestFile.FullName) {
        try {
            $entries = Get-Content -Path $newestFile.FullName | ForEach-Object { $_ | ConvertFrom-Json }
            if ($entries.Count -gt 0 -and $entries[0].timestamp) {
                Update-LastTimestamp -newTimestamp $entries[0].timestamp
            }
            Process-LogFile -filePath $newestFile.FullName -lastTimestamp $entries[0].timestamp
        } catch {
            #Write-Host "Error processing new log file: $_" -ForegroundColor Red
        }
		$Global:GameRunning = $true 
		Write-Host "Game is running" -ForegroundColor Green -BackgroundColor Yellow
    }
}

Write-Host "FileSystemWatcher is monitoring $inputFolderPath for changes..." -ForegroundColor Yellow 

while ($true) {
    Wait-Event  # Wait for events indefinitely
}
