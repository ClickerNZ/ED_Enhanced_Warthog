# v25 – Process Journal using line-count tracking (Approach #1)
# Replaces timestamp-based filtering with "last line number" tracking per file.

param (
    [string]$inputFolderPath    = "D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous",
    [string]$outputFolderPath   = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Output",
    [string]$trackingFilePath   = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Output\Tracking.json"
)

# Path to our output JSON
$JsonFilePath = Join-Path -Path $outputFolderPath -ChildPath "MyJournalData.json"

# Ensure directories exist
if (-not (Test-Path $outputFolderPath)) { New-Item -Path $outputFolderPath -ItemType Directory | Out-Null }

# Initialize tracking file if missing
if (-not (Test-Path $trackingFilePath)) {
    @{ lastLines = @{} } | ConvertTo-Json -Compress | Set-Content -Path $trackingFilePath -Encoding ascii
}

# Module imports
$customModulePath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Modules"
if (-not ($env:PSModulePath -like "*$customModulePath*")) { $env:PSModulePath += ";$customModulePath" }
Import-Module TransformUtilities -ErrorAction Stop
Import-Module TTS               -ErrorAction Stop

# TTS startup
$voice = "Microsoft Catherine"
$rate  = 0
$volume= 75
[TTS]::SpeakText("Journal processor version 25 loading", $voice, $rate, $volume)

# Set window title
try { $host.UI.RawUI.WindowTitle = "Process Journal v25" } catch {}

# Load lookup maps
Import-MapFile -FilePath "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Lookup\EDData.json"

Write-Host "ProcessJournal v25 (line-count tracking)" -ForegroundColor Green

# === Global data initialization ===
function Initialize-GlobalVariables {
    if (-not (Test-Path $JsonFilePath)) {
        $defaults = @{ 
            CMDRName      = "not set"; ShipName      = "not set"; ShipType      = "not set";
            StationName   = "not set"; StationType   = "not set"; SystemName    = "not set";
            BodyName      = "not set"; OrganicFound  = "not set";
            DockingStatus = "not set"; DeniedReason  = "not set"; LandingPad    = "not set";
            ActiveFighter = "FALSE" 
        }
        $defaults | ConvertTo-Json | Set-Content $JsonFilePath
    }
    $data = Get-Content $JsonFilePath | ConvertFrom-Json
    foreach ($prop in $data.PSObject.Properties) {
        Set-Variable -Name $prop.Name -Value $prop.Value -Scope Global
    }
}

# Compare new vs old, then update JSON
function Compare-And-UpdateVariables {
    $keys = @(
        'CMDRName','ShipName','ShipType','StationName','StationType',
        'SystemName','BodyName','OrganicFound','DockingStatus',
        'DeniedReason','LandingPad','ActiveFighter'
    )
    $changed = $false
    foreach ($k in $keys) {
        $old = Get-Variable -Name $k   -Scope Global -ValueOnly
        $new = Get-Variable -Name "new$k" -Scope Global -ValueOnly
        if ($new -ne $old) { $changed = $true; break }
    }
    if ($changed) {
        foreach ($k in $keys) {
            $val = Get-Variable -Name "new$k" -Scope Global -ValueOnly
            Set-Variable -Name $k -Value $val -Scope Global
        }
        # Write out JSON
        $updated = [ordered]@{
            timestamp      = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss');
            CMDRName       = $Global:CMDRName;
            ShipName       = $Global:ShipName;
            ShipType       = $Global:ShipType;
            StationName    = $Global:StationName;
            StationType    = $Global:StationType;
            SystemName     = $Global:SystemName;
            BodyName       = $Global:BodyName;
            OrganicFound   = $Global:OrganicFound;
            DockingStatus  = $Global:DockingStatus;
            DeniedReason   = $Global:DeniedReason;
            LandingPad     = $Global:LandingPad;
            ActiveFighter  = $Global:ActiveFighter
        }
        $updated | ConvertTo-Json -Compress | Set-Content $JsonFilePath
        Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] : Updated MyJournalData.json" -ForegroundColor Cyan
    }
}

# === Tracking file helpers ===
function Load-TrackingData {
    return Get-Content $trackingFilePath | ConvertFrom-Json
}

function Save-TrackingData($data) {
    $data | ConvertTo-Json -Compress | Set-Content -Path $trackingFilePath -Encoding ascii
}

function Get-LastLineCount($fileName) {
    $t = Load-TrackingData
    if ($t.lastLines.ContainsKey($fileName)) { return [int]$t.lastLines[$fileName] }
    return 0
}

function Update-LastLineCount($fileName, $count) {
    $t = Load-TrackingData
    $t.lastLines[$fileName] = $count
    Save-TrackingData $t
}

# === Core processing ===
function Process-NewLines {
    param([string]$filePath)
    $fileName = Split-Path -Leaf $filePath
    $prevCount = Get-LastLineCount $fileName
    $allLines  = Get-Content -Path $filePath
    $total     = $allLines.Count
    if ($total -le $prevCount) { return }
    $newLines = $allLines[$prevCount..($total-1)]
    foreach ($line in $newLines) {
        try {
            $entry = $line | ConvertFrom-Json
        } catch { continue }
        $now = (Get-Date).ToString('HH:mm:ss')
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
#			"DockingRequested" {
#				$Global:RequestStation = $entry.StationName
#				$Global:newDockingStatus = "Requested"
#				if ($Global:Debug) {
#					if (-not $Global:GameRunning) {
#						Write-Host "[$updatedTimestamp] : Event: DockingRequested, StationName = $Global:RequestStation" -ForegroundColor Yellow 
#					}
#					else {
#						Write-Host "[$updatedTimestamp] : Event: DockingRequested, StationName = $Global:RequestStation" -ForegroundColor Cyan 
#					}
#				}																											
#			}
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
    }
    # update tracker
    Update-LastLineCount $fileName $total
    # propagate changes
    Compare-And-UpdateVariables
}

# Get newest log file
function Get-NewestLogFile {
    $logs = Get-ChildItem -Path $inputFolderPath -Filter 'Journal*.log' |
            Sort-Object LastWriteTime -Descending
    return $logs | Select-Object -First 1
}

# === Startup processing ===
$Global:GameRunning = $false
$Global:DEBUG       = $true
Initialize-GlobalVariables
# seed new* variables
foreach ($prop in (Get-Variable -Scope Global | Where-Object Name -match '^(CMDRName|ShipName|ShipType|StationName|StationType|SystemName|BodyName|OrganicFound|DockingStatus|DeniedReason|LandingPad|ActiveFighter)$')) {
    Set-Variable -Name "new$($prop.Name)" -Value $prop.Value -Scope Global
}

# Process existing journal file
$first = Get-NewestLogFile
if ($first) { Process-NewLines -filePath $first.FullName }

# === FileSystemWatcher ===
$watcher1 = New-Object System.IO.FileSystemWatcher
$watcher1.Path                = $inputFolderPath
$watcher1.Filter              = 'Journal*.log'
$watcher1.IncludeSubdirectories= $false
$watcher1.EnableRaisingEvents = $true

Register-ObjectEvent -InputObject $watcher1 -EventName Changed -Action {
    param($s,$e)
    $Global:GameRunning = $true
    if ($e.FullPath -eq (Get-NewestLogFile).FullName) {
        Process-NewLines -filePath $e.FullPath
    }
}
Register-ObjectEvent -InputObject $watcher1 -EventName Created -Action {
    param($s,$e)
    Write-Host "Detected new file: $($e.FullPath)" -ForegroundColor Yellow
    Process-NewLines -filePath $e.FullPath
    $Global:GameRunning = $true
    Write-Host "Game is running" -ForegroundColor Green -BackgroundColor Yellow
}

Write-Host "FileSystemWatcher is monitoring $inputFolderPath for new entries..." -ForegroundColor Yellow
while ($true) { Wait-Event }
