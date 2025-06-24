# v30 – Use LoadGameDetect counter to detect when game reloads via 'LoadGame' event
#		(used in TARGET via menulog code)

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
$rate  = 1
$volume= 75
[TTS]::SpeakText("Journal processor version 30 loading", $voice, $rate, $volume)

# Set window title
try { $host.UI.RawUI.WindowTitle = "Process Journal v30" } catch {}

# Load lookup maps
Import-MapFile -FilePath "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Lookup\EDData.json"

Write-Host "ProcessJournal v30" -ForegroundColor Green

# === Global data initialization ===
function Initialize-GlobalVariables {
    if (-not (Test-Path $JsonFilePath)) {
        $defaults = @{
			LoadGameDetect = 0; CMDRName = "not set"; ShipName = "not set"; ShipType = "not set";
            StationName = "not set"; StationType = "not set"; SystemName = "not set";
            BodyName = "not set"; OrganicFound = "not set";
            DockingStatus = "not set"; DeniedReason = "not set"; LandingPad = "not set";
			Modules = 0; ActiveFighter = $false;
			InputCMD = "not set"; CMDParameter = "not set";
        }
        $defaults | ConvertTo-Json | Set-Content $JsonFilePath
    }
    $data = Get-Content $JsonFilePath | ConvertFrom-Json
    foreach ($prop in $data.PSObject.Properties) {
        Set-Variable -Name $prop.Name -Value $prop.Value -Scope Global
    }
	
	# Read the old bitmask for compare:
	$Global:Modules = [int](Get-Content $JsonFilePath | ConvertFrom-Json).Modules
}

# Compare new vs old, then update JSON
function Compare-And-UpdateVariables {
    $keys = @(
        'LoadGameDetect','CMDRName','ShipName','ShipType','StationName','StationType',
        'SystemName','BodyName','OrganicFound','DockingStatus',
        'DeniedReason','LandingPad','Modules','ActiveFighter','InputCMD','CMDParameter'
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
			LoadGameDetect = $Global:LoadGameDetect;
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
			Modules        = $Global:Modules
			ActiveFighter  = $Global:ActiveFighter
			InputCMD       = $Global:InputCMD
			CMDParameter = $Global:CMDParameter
        }
#       $updated | ConvertTo-Json -Compress | Set-Content $JsonFilePath
		$json = $updated | ConvertTo-Json -Compress
		$json = $json -replace '\\u0027', "'"
		[System.IO.File]::WriteAllText($JsonFilePath, $json, [System.Text.UTF8Encoding]::new($false))

	#	$dec  = $Global:Modules
    #   $hex  = ('0x{0:X}' -f $dec)
    #   $bin  = [Convert]::ToString($dec,2).PadLeft($Global:moduleNames.Count,'0')
    #   Write-Host "Modules changed: DEC:$dec  HEX:$hex  BIN:$bin" -ForegroundColor Magenta
	#	Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] : Updated MyJournalData.json" -ForegroundColor Blue		
    }
}

# === Tracking file helpers ===
function Load-TrackingData {
    return Get-Content $trackingFilePath | ConvertFrom-Json
}

function Save-TrackingData($data) {
    $data | ConvertTo-Json -Compress | Set-Content -Path $trackingFilePath -Encoding ascii
}

function Get-LastLineCount {
    param([string]$fileName)
    $t = Load-TrackingData
    if ($t.lastLines.PSObject.Properties.Name -contains $fileName) {
        return [int]$t.lastLines.$fileName
    }
    return 0
}

function Update-LastLineCount {
    param(
        [string]$fileName,
        [int]   $count
    )
    $t = Load-TrackingData
    # Add or update the property for this file
    $t.lastLines | Add-Member -NotePropertyName $fileName -NotePropertyValue $count -Force
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
		$localtime = $((Get-Date).ToString('HH:mm:ss'))
        switch ($entry.event) {
			"Commander" {
				if ("Name" -in $entry.PSObject.Properties.Name) {
					$Global:newCMDRName = $entry.Name
					if ($Global:Debug) {
						if (-not $Global:GameRunning) {
							Write-Host "[$localtime] : Event: Commander, Name = $Global:newCMDRName" -ForegroundColor Yellow 
						}
						else {
							Write-Host "[$localtime] : Event: Commander, Name = $Global:newCMDRName" -ForegroundColor Cyan
						}
					}
				}
			}
			"Statistics" {				
				$Global:newLoadGameDetect++
				if($Global:Debug) {
					if (-not $Global:GameRunning) {
						Write-Host "[$localtime] : Event: LoadGame, LoadGameDetect = $Global:newLoadGameDetect" -ForegroundColor Yellow
					}
					else {
						Write-Host "[$localtime] : Event: LoadGame, LoadGameDetect = $Global:newLoadGameDetect" -ForegroundColor Cyan 
					}
				}
			}
			"LoadGame" {	
#				$Global:newLoadGameDetect++
				if ("Ship" -in $entry.PSObject.Properties.Name) {
					$ShipType = Get-MappedValue -MapName "ShipType_map" -Key $entry.ship
					$Global:newShipType = $ShipType
					if ($Global:Debug) {
						if (-not $Global:GameRunning) {
#							Write-Host "[$localtime] : Event: LoadGame, LoadGameDetect = $Global:newLoadGameDetect" -ForegroundColor Yellow
							Write-Host "[$localtime] : Event: LoadGame, Ship = $Global:newShipType" -ForegroundColor Yellow 
						}
						else {
#							Write-Host "[$localtime] : Event: LoadGame, LoadGameDetect = $Global:newLoadGameDetect" -ForegroundColor Cyan 							
							Write-Host "[$localtime] : Event: LoadGame, Ship = $Global:newShipType" -ForegroundColor Cyan 
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
							Write-Host "[$localtime] : Event: Docked, StationName = $Global:newStationName" -ForegroundColor Yellow 
							Write-Host "[$localtime] : Event: Docked, DockingStatus = $Global:newDockingStatus" -ForegroundColor Yellow 
							Write-Host "[$localtime] : Event: Docked, DeniedReason = $Global:newDeniedReason" -ForegroundColor Yellow 
							Write-Host "[$localtime] : Event: Docked, LandingPad = $Global:newLandingPad" -ForegroundColor Yellow 
						}
						else {
							Write-Host "[$localtime] : Event: Docked, StationName = $Global:newStationName" -ForegroundColor Cyan 
							Write-Host "[$localtime] : Event: Docked, LandingPad = $Global:newLandingPad" -ForegroundColor Cyan 
						}
					}							
				}
				if ("StationType" -in $entry.PSObject.Properties.Name) {
					$Global:newStationType = $entry.StationType
					if ($Global:Debug) {
						if (-not $Global:GameRunning) {
							Write-Host "[$localtime] : Event: Docked, StationType = $Global:newStationType" -ForegroundColor Yellow 
						}
						else {
							Write-Host "[$localtime] : Event: Docked, StationType = $Global:newStationType" -ForegroundColor Cyan
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
							Write-Host "[$localtime] : Event: ShipyardSwap, ShipType = $Global:newShipType" -ForegroundColor Yellow 
						}
						else {
							Write-Host "[$localtime] : Event: ShipyardSwap, ShipType = $Global:newShipType" -ForegroundColor Cyan 
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
							Write-Host "[$localtime] : Event: Loadout, Ship = $Global:newShipType" -ForegroundColor Yellow 
						}
						else {
							Write-Host "[$localtime] : Event: Loadout, Ship = $Global:newShipType" -ForegroundColor Cyan									
						}
					}														
				}
				if ("ShipName" -in $entry.PSObject.Properties.Name) {
					$Global:newShipName = $entry.ShipName
					if ($Global:Debug) {
						if (-not $Global:GameRunning) {
							Write-Host "[$localtime] : Event: Loadout, ShipName = $Global:newShipName" -ForegroundColor Yellow 
						}
						else {
							Write-Host "[$localtime] : Event: Loadout, ShipName = $Global:newShipName" -ForegroundColor Cyan
						}
					}														
				}

				foreach ($name in $Global:moduleNames) {
					$Global:moduleFlags[$name] = $false
				}
				foreach ($mod in $entry.Modules) {
					foreach ($fragment in $Global:moduleMap.Keys) {
						if ($mod.Item -like "*$fragment*") {
							$Global:moduleFlags[ $Global:moduleMap[$fragment] ] = $true
						}
					}
				}

				$mask = Encode-ModulesBitmask -Flags $Global:moduleFlags
				$bin  = [Convert]::ToString($mask,2).PadLeft($Global:moduleNames.Count,'0')
				Write-Host ("->Encoded mask: DEC:{0}  BIN(msb->lsb):{1}" -f $mask, $bin) -ForegroundColor Magenta

				$Global:newModules = $mask


				$Global:newModules = Encode-ModulesBitmask -Flags $Global:moduleFlags
			}	
			"Location" {
				if ("StarSystem" -in $entry.PSObject.Properties.Name) {
					$Global:newSystemName = $entry.StarSystem
					if ($Global:Debug) {
						if (-not $Global:GameRunning) {
							Write-Host "[$localtime] : Event: Location, StarSystem = $Global:newSystemName" -ForegroundColor Yellow 
						}
						else {
							Write-Host "[$localtime] : Event: Location, StarSystem = $Global:newSystemName" -ForegroundColor Cyan
						}
					}																					
				}
				if ("Body" -in $entry.PSObject.Properties.Name) {
					$Global:newBodyName = $entry.Body
					if ($Global:Debug) {
						if (-not $Global:GameRunning) {
							Write-Host "[$localtime] : Event: Location, Body = $Global:newBodyName" -ForegroundColor Yellow 
						}
						else {
							Write-Host "[$localtime] : Event: Location, Body = $Global:newBodyName" -ForegroundColor Cyan
						}
					}																					
				}
				if ("StationName" -in $entry.PSObject.Properties.Name) {
					$Global:newStationName = $entry.StationName
					if ($Global:Debug) {
						if (-not $Global:GameRunning) {
							Write-Host "[$localtime] : Event: Location, StationName = $Global:newStationName" -ForegroundColor Yellow 
						}
						else {
							Write-Host "[$localtime] : Event: Location, StationName = $Global:newStationName" -ForegroundColor Cyan
						}
					}																					
				}
				if ("StationType" -in $entry.PSObject.Properties.Name) {
					$Global:newStationType = $entry.StationType
					if ($Global:Debug) {
						if (-not $Global:GameRunning) {
							Write-Host "[$localtime] : Event: Location, StationType = $Global:newStationType" -ForegroundColor Yellow 
						}
						else {
							Write-Host "[$localtime] : Event: Location, StationType = $Global:newStationType" -ForegroundColor Cyan
						}
					}																					
				}
			}
			"Touchdown" {
				if ("Body" -in $entry.PSObject.Properties.Name) {
					$Global:newBodyName = $entry.Body
					if ($Global:Debug) {
						if (-not $Global:GameRunning) {
							Write-Host "[$localtime] : Event: TouchDown, Body = $Global:newBodyName" -ForegroundColor Yellow 
						}
						else {
							Write-Host "[$localtime] : Event: TouchDown, Body = $Global:newBodyName" -ForegroundColor Cyan
						}
					}																					
				}
			}
			"DockingRequested" {									# Not, strictly speaking, required as we capture this within TARGET already
				$Global:RequestStation = $entry.StationName
				$Global:newDockingStatus = "Requested"
				if ($Global:Debug) {
					if (-not $Global:GameRunning) {
						Write-Host "[$localtime] : Event: DockingRequested, StationName = $Global:RequestStation" -ForegroundColor Yellow 
					}
					else {
						Write-Host "[$localtime] : Event: DockingRequested, StationName = $Global:RequestStation" -ForegroundColor Cyan 
					}
				}																											
			}
			"DockingCancelled" {
				$Global:RequestStation = $entry.StationName
				$Global:newDockingStatus = "Cancelled"
				$Global:newLandingPad = "not set"
				$Global:newDeniedReason = "not set"
				if ($Global:Debug) {
					if (-not $Global:GameRunning) {
						Write-Host "[$localtime] : Event: DockingCancelled, StationName = $Global:RequestStation" -ForegroundColor Yellow 
					}
					else {
						Write-Host "[$localtime] : Event: DockingCancelled, StationName = $Global:RequestStation" -ForegroundColor Cyan 
					}
				}																											
			}
			"DockingDenied" {
				$Global:RequestStation = $entry.StationName
				$Global:newDockingStatus = "Denied"
				$Global:newDeniedReason = $entry.Reason
				$Global:newLandingPad = "not set"
				if ($Global:Debug) {
					if (-not $Global:GameRunning) {
						#Write-Host "[$localtime] : Event: DockingDenied, StationName = $Global:RequestStation" -ForegroundColor Yellow 
						Write-Host "[$localtime] : Event: DockingDenied, Reason = $Global:newDeniedReason" -ForegroundColor Yellow 
					}
					else {
						#Write-Host "[$localtime] : Event: DockingDenied, StationName = $Global:RequestStation" -ForegroundColor Cyan 
						Write-Host "[$localtime] : Event: DockingDenied, Reason = $Global:newDeniedReason" -ForegroundColor Cyan 
					}
				}																																	
			}
			"DockingTimeout" {
				$Global:RequestStation = $entry.StationName
				$Global:newDockingStatus = "Timeout"
				$Global:newDeniedReason = "not set"
				$Global:newLandingPad = "not set"
				if ($Global:Debug) {
					if (-not $Global:GameRunning) {
						Write-Host "[$localtime] : Event: DockingTimeout, StationName = $Global:RequestStation" -ForegroundColor Yellow 
					}
					else {
						Write-Host "[$localtime] : Event: DockingTimeout, StationName = $Global:RequestStation" -ForegroundColor Cyan 
					}
				}																																	
			}					
			"DockingGranted" {
				$Global:newDockingStatus = "Granted"
				$Global:newLandingPad = $entry.LandingPad
				$Global:newStationName = $entry.StationName
				$Global:newDeniedReason = "not denied"
				$Global:StationType = $entry.StationType
				if ($Global:Debug) {
					if (-not $Global:GameRunning) {
						Write-Host "[$localtime] : Event: DockingGranted, StationName = $Global:newStationName" -ForegroundColor Yellow 
						Write-Host "[$localtime] : Event: DockingGranted, LandingPad = $Global:newLandingPad" -ForegroundColor Yellow 
					}
					else {
						Write-Host "[$localtime] : Event: DockingGranted, StationName = $Global:newStationName" -ForegroundColor Cyan  
						Write-Host "[$localtime] : Event: DockingGranted, LandingPad = $Global:newLandingPad" -ForegroundColor Cyan 
					}
				}
			}
			"Undocked" {
				$Global:RequestStation = $entry.StationName
				$Global:newDockingStatus = "Undocked"
				$Global:newDeniedReason = "not set"
				$Global:newLandingPad = "not set"
				$Global:newStationName = "not set"
				$Global:newStationType = "not set"
				if ($Global:Debug) {
					if (-not $Global:GameRunning) {
						Write-Host "[$localtime] : Event: Undocked, StationName = $Global:RequestStation" -ForegroundColor Yellow 
					}
					else {
						Write-Host "[$localtime] : Event: Undocked, StationName = $Global:RequestStation" -ForegroundColor Cyan 
					}
				}																											
			}					
			"FSDJump" {
				if ("StarSystem" -in $entry.PSObject.Properties.Name) {
					$Global:newSystemName = $entry.StarSystem
					if ($Global:Debug) {
						if (-not $Global:GameRunning) {
							Write-Host "[$localtime] : Event: FSDJump, StarSystem = $Global:newSystemName" -ForegroundColor Yellow 
						}
						else {
							Write-Host "[$localtime] : Event: FSDJump, StarSystem = $Global:newSystemName" -ForegroundColor Cyan
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
							Write-Host "[$localtime] : Event: ScanOrganic, Species_Localised = $Global:newOrganicFound" -ForegroundColor Yellow 
						}
						else {
							Write-Host "[$localtime] : Event: ScanOrganic, Species_Localised = $Global:newOrganicFound" -ForegroundColor Cyan  
						}
					}																					
				}
			}
			"LaunchFighter" {
				$Global:newActiveFighter = $true
				if ($Global:Debug) {
					if (-not $Global:GameRunning) {
						Write-Host "[$localtime] : Event: LaunchFighter, ActiveFighter = $Global:newActiveFighter" -ForegroundColor Yellow 
					}
					else {
						Write-Host "[$localtime] : Event: LaunchFighter, ActiveFighter = $Global:newActiveFighter" -ForegroundColor Cyan
					}
				}																											
			}
			"FighterDestroyed" {
				$Global:newActiveFighter = $false 
				if ($Global:Debug) {
					if (-not $Global:GameRunning) {
						Write-Host "[$localtime] : Event: FighterDestroyed, ActiveFighter = $Global:newActiveFighter" -ForegroundColor Yellow 
					}
					else {
						Write-Host "[$localtime] : Event: FighterDestroyed, ActiveFighter = $Global:newActiveFighter" -ForegroundColor Cyan
					}
				}																											
			}
			"DockFighter" {
				$Global:newActiveFighter = $false 
				if ($Global:Debug) {
					if (-not $Global:GameRunning) {
						Write-Host "[$localtime] : Event: DockFighter, ActiveFighter = $Global:newActiveFighter" -ForegroundColor Yellow 
					}
					else {
						Write-Host "[$localtime] : Event: DockFighter, ActiveFighter = $Global:newActiveFighter" -ForegroundColor Cyan
					}
				}																											
			}
			"SendText" {
				if (("Message" -in $entry.PSObject.Properties.Name) -and $entry.Message.StartsWith("!set")) {
					$msg = $entry.Message.Substring(5)   # chop off "!set "

					# split on whitespace into at most 2 pieces
					#   part[0] = the setting name
					#   part[1] = everything else
					$part = $msg -split '\s+', 2

					# assign to globals (or whatever scope you like)
					$Global:newInputCMD				= $part[0]
					$Global:newCMDParameter    = $part[1]

					if ($Global:Debug) {
						if (-not $Global:GameRunning) {
							Write-Host "[$localtime] : Event: SendText, InputCMD = $Global:newInputCMD" -ForegroundColor Yellow 
							Write-Host "[$localtime] : Event: SendText, CMDParameter = $Global:newCMDParameter" -ForegroundColor Yellow 
						}
						else {
							Write-Host "[$localtime] : Event: SendText, InputCMD = $Global:newInputCMD" -ForegroundColor Cyan
							Write-Host "[$localtime] : Event: SendText, CMDParameter = $Global:CMDParameter" -ForegroundColor Cyan
						}
					}																					
				}
			}
			"Shutdown" {
				$localtime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
				Write-Host "[$localtime] Shutdown event encountered: Game Running is $Global:GameRunning" -ForegroundColor Yellow -BackgroundColor Green

				# reset LoadGameDetect and save to MyJournalData.json 
				$Global:newLoadGameDetect = 0;
				Compare-And-UpdateVariables

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

function Decode-ModulesBitmask {
    [CmdletBinding()] param(
        [Parameter(Mandatory)][int]   $Mask,
        [Parameter(Mandatory)][string[]] $Names
    )
    $flags = [ordered]@{}
    for ($i = 0; $i -lt $Names.Count; $i++) {
        # test bit i
        $flags[$Names[$i]] = ( ($Mask -band (1 -shl $i)) -ne 0 )
    }
    return $flags
}

function Encode-ModulesBitmask {
    [CmdletBinding()] param(
        # accept anything that supports lookup
        [Parameter(Mandatory)] $Flags
    )
    [int]$mask = 0
    for ($i = 0; $i -lt $Global:moduleNames.Count; $i++) {
        $name = $Global:moduleNames[$i]
        if ($Flags[$name]) {
            # set bit at position $i
            $mask = $mask -bor (1 -shl $i)
        }
    }
    return $mask
}

# === Startup processing ===

$Global:GameRunning    = $false
$Global:DEBUG          = $true

# The array that defines your bit positions (bit 0 → SCOPresent, bit 1 → FighterPresent, …)
$Global:moduleNames = @(
    'SCOPresent',
    'FighterPresent',
    'SRVPresent',
    'HeatsinkPresent',
    'ChaffLauncherPresent',
    'SCBPresent',
    'ECMPresent',
	'LimpetPresent'
)

# A simple map of “key fragment” → which flag to set
$Global:moduleMap = @{
    hyperdrive_overcharge      = 'SCOPresent'
    fighterbay                 = 'FighterPresent'
    buggybay                   = 'SRVPresent'
    heatsinklauncher           = 'HeatsinkPresent'
    chafflauncher              = 'ChaffLauncherPresent'
    shieldcellbank             = 'SCBPresent'
    electroniccountermeasure   = 'ECMPresent'
	dronecontrol               = 'LimpetPresent'
}

# Initialize your flags table
$Global:moduleFlags = [ordered]@{}
foreach ($name in $Global:moduleNames) {
    $Global:moduleFlags[$name] = $false
}

Initialize-GlobalVariables

# seed new* variables
foreach ($prop in (Get-Variable -Scope Global | Where-Object Name -match '^(LoadGameDetect|CMDRName|ShipName|ShipType|StationName|StationType|SystemName|BodyName|OrganicFound|DockingStatus|DeniedReason|LandingPad|Modules|ActiveFighter|InputCMD|CMDParameter)$')) {	
    Set-Variable -Name "new$($prop.Name)" -Value $prop.Value -Scope Global
}

# Not sure this should go here...not sure above will seed this var with the init value of $false
$Global:newActiveFighter = $false
$Global:newInputCMD = "not set"
$Global:newCMDParameter = "not set"  

# Process existing journal file
$first = Get-NewestLogFile
if ($first) { Process-NewLines -filePath $first.FullName }

$timer = New-Object System.Timers.Timer 500
$timer.AutoReset = $true
$timer.Enabled   = $true

Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
    # ensure you only ever process the current journal
    $log = Get-NewestLogFile
    if ($log) { Process-NewLines -filePath $log.FullName }
}

# === FileSystemWatcher ===
$watcher1 = New-Object System.IO.FileSystemWatcher
$watcher1.Path                = $inputFolderPath
$watcher1.Filter              = 'Journal*.log'
$watcher1.IncludeSubdirectories= $false

# watch for content changes
$watcher1.NotifyFilter = [System.IO.NotifyFilters]'LastWrite, Size'

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

#Write-Host "FileSystemWatcher is monitoring $inputFolderPath for new entries..." -ForegroundColor Yellow
Write-Host "Monitoring journal (watcher + 500 ms poll)..." -ForegroundColor Yellow
while ($true) { Wait-Event }
