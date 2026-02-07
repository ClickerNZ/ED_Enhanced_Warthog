# v33 	- ATC Chatter functions added - Grabs any NPC chatter sent to LOCAL and sends to [TTS]
#		- Global $script:StatusPath created so we can easily grab status.json key/values
#
# ProcessJournal.ps1
#
# This is an Elite Dangerous / TARGET Script helper application.
# It watches the Elite Dangerous journal file for changes then grabs selected key values and writes these
# to MyJournalData.json JSON file or uses Windows Text-To-Speech to announce certain events.
#
# My Warthog TARGET Script periodically processes MyJournalData.json and uses the key/values in various ways.
# The script can also write special values to the Journal file for this application to process.
#

# The following paths are created by default when installing Elite Dangerous and my TARGET Scripts.
# They may be changed when installing, so you must ensure the below paths are correct.

param (
	# Make sure this path points to where Elite Dangerous writes the journal files to...
    [string]$inputFolderPath    = "D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous",

	# Make sure these paths have been created and available...
    [string]$outputFolderPath   = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Output",
    [string]$trackingFilePath   = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Output\Tracking.json"
)

$MyVersion = 33

# Path to our output JSON
$JsonFilePath = Join-Path -Path $outputFolderPath -ChildPath "MyJournalData.json"

# Ensure directories exist
if (-not (Test-Path $outputFolderPath)) { New-Item -Path $outputFolderPath -ItemType Directory | Out-Null }

# --- Status.json path (standard ED location) ---
$script:StatusPath = Join-Path -Path $inputFolderPath -ChildPath "Status.json" 

# Initialize tracking file if missing
if (-not (Test-Path $trackingFilePath)) {
    @{ lastLines = @{} } | ConvertTo-Json -Compress | Set-Content -Path $trackingFilePath -Encoding ascii
}

# Module imports
$customModulePath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Modules"
if (-not ($env:PSModulePath -like "*$customModulePath*")) { $env:PSModulePath += ";$customModulePath" }
Import-Module TransformUtilities	-ErrorAction Stop
Import-Module TTS               	-ErrorAction Stop
Import-Module ATCChatter			-ErrorAction Stop 

# Enables ATC Chatter function for ReceiveText trap 
$Global:ATCChatter = $true 

<#
# DEBUG: Testing the ATCChatter module...
Add-ATCChatter "ATC chatter test one" "Station"
Add-ATCChatter "ATC chatter test two" "Traffic"
Add-ATCChatter "ATC chatter test three" "Security"
Invoke-ATCChatter
Invoke-ATCChatter
Invoke-ATCChatter
#>

# TTS startup
# The following voice should be installed on your Windows PC to work as intended.
# If this voice is unavailable the default Windows TTS voice will be used.
# Refer:
# https://support.microsoft.com/en-nz/help/22805/windows-10-supported-narrator-languages-voices 
# https://www.ghacks.net/2018/08/11/unlock-all-windows-10-tts-voices-system-wide-to-get-more-of-them/


$voice = "Microsoft Catherine"
$rate  = 1
$volume= 100
[TTS]::SpeakText("Journal processor version $MyVersion loading", $voice, $rate, $volume)

<#
[TTS]::SpeakText("Catherine, Journal processor version $MyVersion loading", "Microsoft Catherine", $rate, $volume)
[TTS]::SpeakText("James, Journal processor version $MyVersion loading", "Microsoft James", $rate, $volume)
[TTS]::SpeakText("David, Journal processor version $MyVersion loading", "Microsoft David Desktop", $rate, $volume)
[TTS]::SpeakText("Zira, Journal processor version $MyVersion loading", "Microsoft Zira Desktop", $rate, $volume)
[TTS]::SpeakText("Heera, Journal processor version $MyVersion loading", "Microsoft Heera", $rate, $volume)
[TTS]::SpeakText("Ravi, Journal processor version $MyVersion loading", "Microsoft Ravi", $rate, $volume)
[TTS]::SpeakText("Sean, Journal processor version $MyVersion loading", "Microsoft Sean", $rate, $volume)
[TTS]::SpeakText("Richard, Journal processor version $MyVersion loading", "Microsoft Richard", $rate, $volume)
[TTS]::SpeakText("Linda, Journal processor version $MyVersion loading", "Microsoft Linda", $rate, $volume)
[TTS]::SpeakText("Mark, Journal processor version $MyVersion loading", "Microsoft Mark", $rate, $volume)
#>

# Set window title
try { $host.UI.RawUI.WindowTitle = "Journal Processor v$MyVersion" } catch {}

# Load lookup maps
Import-MapFile -FilePath "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Lookup\EDData.json"

Write-Host "ProcessJournal v$MyVersion" -ForegroundColor Green

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
        $jsonDefaults = $defaults | ConvertTo-Json -Compress
        [System.IO.File]::WriteAllText($JsonFilePath, $jsonDefaults, [System.Text.Encoding]::ASCII)
#        $defaults | ConvertTo-Json | Set-Content $JsonFilePath
    }
    $data = Get-Content -Path $JsonFilePath -Encoding ascii | ConvertFrom-Json
#    $data = Get-Content $JsonFilePath | ConvertFrom-Json
    foreach ($prop in $data.PSObject.Properties) {
        Set-Variable -Name $prop.Name -Value $prop.Value -Scope Global
    }
	
	# Read the saved bitmask to compare:
	$Global:Modules = [int](Get-Content -Path $JsonFilePath -Encoding ascii | ConvertFrom-Json).Modules
#	$Global:Modules = [int](Get-Content $JsonFilePath | ConvertFrom-Json).Modules
}

# Convert strings to plain ASCII for TARGET compatibility.
# - Fixes “smart” punctuation (e.g., ’) and then forces ASCII (anything else becomes '?').
function Convert-ToTargetAscii {
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) { return $null }

    # Common smart punctuation -> ASCII
    $Text = $Text -replace [char]0x2019, "'"   # ’
    $Text = $Text -replace [char]0x2018, "'"   # ‘
    $Text = $Text -replace [char]0x201C, '"'   # “
    $Text = $Text -replace [char]0x201D, '"'   # ”
    $Text = $Text -replace [char]0x2013, '-'   # –
    $Text = $Text -replace [char]0x2014, '-'   # —
    $Text = $Text -replace [char]0x2026, '...' # …
    $Text = $Text -replace [char]0x00A0, ' '   # non-breaking space

    # Force ASCII for TARGET (unrepresentable chars -> '?')
    return [System.Text.Encoding]::ASCII.GetString([System.Text.Encoding]::ASCII.GetBytes($Text))
}


# Compare new vs old, then update JSON
function Compare-And-UpdateVariables {
    $keys = @(
        'LoadGameDetect','CMDRName','ShipName','ShipType','StationName','StationType',
        'SystemName','BodyName','OrganicFound','DockingStatus',
        'DeniedReason','LandingPad','Modules','ActiveFighter','InputCMD','CMDParameter',
        'destHeading','destDistance'
    )

    $changed = $false
    foreach ($k in $keys) {
        $old = Get-Variable -Name $k -Scope Global -ValueOnly
        $new = Get-Variable -Name "new$k" -Scope Global -ValueOnly
        if ($new -ne $old) {
            $changed = $true
            break
        }
    }

    if ($changed) {
        foreach ($k in $keys) {
            $val = Get-Variable -Name "new$k" -Scope Global -ValueOnly
            Set-Variable -Name $k -Value $val -Scope Global
        }

        $updated = [ordered]@{
            timestamp      = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            LoadGameDetect = $Global:LoadGameDetect
            CMDRName       = $Global:CMDRName
            ShipName       = $Global:ShipName
            ShipType       = $Global:ShipType
            StationName    = $Global:StationName
            StationType    = $Global:StationType
            SystemName     = $Global:SystemName
            BodyName       = $Global:BodyName
            OrganicFound   = $Global:OrganicFound
            DockingStatus  = $Global:DockingStatus
            DeniedReason   = $Global:DeniedReason
            LandingPad     = $Global:LandingPad
            Modules        = $Global:Modules
            ActiveFighter  = $Global:ActiveFighter
            InputCMD       = $Global:InputCMD
            CMDParameter   = $Global:CMDParameter
            destHeading    = $Global:destHeading
            destDistance   = $Global:destDistance
        }

        foreach ($k in @($updated.Keys)) {  # snapshot keys to avoid 'collection was modified' error
            if ($updated[$k] -is [string]) { $updated[$k] = Convert-ToTargetAscii $updated[$k] }
        }

        $json = $updated | ConvertTo-Json -Compress
        $json = $json -replace '\\u0027', "'"
		[System.IO.File]::WriteAllText($JsonFilePath, $json, [System.Text.Encoding]::ASCII)
	}
}

# === Tracking file helpers ===
function Load-TrackingData {
    return Get-Content -Path $trackingFilePath -Encoding ascii | ConvertFrom-Json
#   return Get-Content $trackingFilePath | ConvertFrom-Json
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

#$script:StatusPath = Join-Path $env:USERPROFILE "Saved Games\Frontier Developments\Elite Dangerous\Status.json"
$script:LastStatusWriteUtc = [datetime]::MinValue
$script:NextStatusPollUtc  = [datetime]::MinValue

function Refresh-StatusAndATCState {
    if ([datetime]::UtcNow -lt $script:NextStatusPollUtc) { return }
    $script:NextStatusPollUtc = [datetime]::UtcNow.AddMilliseconds(250)

    if (-not (Test-Path $script:StatusPath)) { return }

    $fi = Get-Item $script:StatusPath -ErrorAction SilentlyContinue
    if (-not $fi) { return }
    if ($fi.LastWriteTimeUtc -le $script:LastStatusWriteUtc) { return }
    $script:LastStatusWriteUtc = $fi.LastWriteTimeUtc

    try {
        $raw = Get-Content $script:StatusPath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return }
        $status = $raw | ConvertFrom-Json
        Update-ATCChatterStateFromStatus $status
    } catch { }
}

# === Core processing ===
function Process-NewLines {
    param([string]$filePath)
    $fileName = Split-Path -Leaf $filePath
    $prevCount = Get-LastLineCount $fileName
    $allLines  = Get-Content -Path $filePath -Encoding utf8
    $total     = $allLines.Count
    if ($total -le $prevCount) { return }
    $newLines = $allLines[$prevCount..($total-1)]

    foreach ($line in $newLines) {
		
		Refresh-StatusAndATCState

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
				if ("Ship" -in $entry.PSObject.Properties.Name) {
					$ShipType = Get-MappedValue -MapName "ShipType_map" -Key $entry.ship
					$Global:newShipType = $ShipType
					if ($Global:Debug) {
						if (-not $Global:GameRunning) {
							Write-Host "[$localtime] : Event: LoadGame, Ship = $Global:newShipType" -ForegroundColor Yellow 
						}
						else {
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

				# DEBUG: Display bit mask for modules installed on ship...
				$mask = Encode-ModulesBitmask -Flags $Global:moduleFlags
				$bin  = [Convert]::ToString($mask,2).PadLeft($Global:moduleNames.Count,'0')
				$Global:newModules = $mask
				# DEBUG: Display bit mask for modules installed on ship...
	#			Write-Host ("->Encoded mask: DEC:{0}  BIN(msb->lsb):{1}" -f $mask, $bin) -ForegroundColor Magenta
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
					#   part[0] = the action or variable name 
					#   part[1] = the variable name (for query) or variable value we wish to set/reset 
					$part = $msg -split '\s+', 2

					switch ($part[0].ToUpper()) {
						"AP" {		# AP = AutoPilot Action 
							# Normalize to upper-case so matching is simpler
							$param = $part[1].ToUpper()

							switch ($param) {
								"ON" {
									if ($Global:destLat -ne $null -and $Global:destLon -ne $null) {
										if (-not $Global:autopilotEnabled) {
											if (Test-AutopilotReady) {
												$Global:autopilotEnabled = $true
												$Global:autopilotTickCount   = 0
												Invoke-AutopilotTick
												$Global:autopilotTimer.Start()
												Write-Host "[$localtime] : Autopilot enabled."
												[TTS]::SpeakText("Set Autopilot ON")
											} else {
												Write-Host "[$localtime] : Invalid Autopilot conditions" -ForegroundColor Yellow
												Write-Host "[$localtime] : $Global:APInvalidReason" -ForegroundColor Yellow
											}
										}
									}
									else {
										Write-Host "[$localtime] : ERROR -- LAT and/or LON not set. Cannot enable autopilot." -ForegroundColor Red
									}
									break
								}
								"OFF" {
									$Global:autopilotEnabled = $false
									$Global:autopilotTimer.Stop()
									Write-Host "[$localtime] : Autopilot disabled."
									[TTS]::SpeakText("Set Autopilot OFF")
									break
								}
								Default {
									Write-Host "[$localtime] : ERROR - Invalid Autopilot parameter '$($part[1])'. Use ON or OFF." -ForegroundColor Yellow
									break
								}
							}
							break
						}
						"LAT" {		# ...to set Latitude for AutoPilot
							if ($part.Count -ge 2 -and $part[1] -match '^-?\d+(\.\d+)?$') {
								$Global:destLat = [double]$part[1]
								Write-Host "[$localtime] : Autopilot LAT set to $($Global:destLat)"
								[TTS]::SpeakText("Set latitude to $Global:destLat")
							} else {
								Write-Host "[$localtime] : ERROR - Invalid LAT value '$($part[1])'" -ForegroundColor Yellow
							}
							break
						}
						"LON" {		# ...to set Longitude for AutoPilot 
							if ($part.Count -ge 2 -and $part[1] -match '^-?\d+(\.\d+)?$') {
								$Global:destLon = [double]$part[1]
								Write-Host "[$localtime] : Autopilot LON set to $($Global:destLon)"
								[TTS]::SpeakText("Set longitude to $Global:destLon")
							} else {
								Write-Host "[$localtime] : ERROR - Invalid LON value '$($part[1])'" -ForegroundColor Yellow
							}
							break
						}
						Default {
							$Global:newInputCMD      = $part[0]
							$Global:newCMDParameter  = $part[1]

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
							break
						}
					}
				}
			}
			
			"ReceiveText" {
				if ($entry.Channel -eq "npc" -and
					-not [string]::IsNullOrWhiteSpace($entry.From) -and
					-not [string]::IsNullOrWhiteSpace($entry.Message_Localised) -and
					$entry.Message -notin @(
						'$STATION_NoFireZone_entered;',
						'$STATION_docking_granted;',
						'$STATION_NoFireZone_exited;'
					))
				{
					$group = Get-ATCGroupForNpcReceiveText $entry

					# If the sender matches the current station name tracked by ProcessJournal, force Station group
					if (-not [string]::IsNullOrWhiteSpace($Global:newStationName)) {
						$fromNorm = $entry.From.Trim() -replace '[’`]', "'"
						$stnNorm  = $Global:newStationName.Trim() -replace '[’`]', "'"

						if ($fromNorm.Equals($stnNorm, [System.StringComparison]::InvariantCultureIgnoreCase)) {
							$group = "Station"
						}
					}

					# Option 1 (strict): speak only the message (your requirement)
					if ($Global:ATCChatter) {
						# Write-Host "ATC queued: $($entry.Message_Localised) (Group=$group, From=$($entry.From))" -ForegroundColor Green
						Add-ATCChatter $entry.Message_Localised $group
					}

					# Option 2 (more ATC-like): uncomment if you want the speaker name too
					# $speaker = $entry.From_Localised
					# if ([string]::IsNullOrWhiteSpace($speaker)) { $speaker = $entry.From }
					#	if ($Global:ATCChatter) {
							# Write-Host "ATC queued: $($speaker): $($entry.Message_Localised) (Group=$group)" -ForegroundColor Cyan
							# Add-ATCChatter ("$speaker. " + $entry.Message_Localised) $group
					#	}
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
					Write-Host "[$localtime] Exiting script in 30 seconds..." -ForegroundColor Yellow
					Start-Sleep -Milliseconds 30000
					Stop-Process -Id $PID -Force  # Forcefully kill script
				}
			}
        }
    }

	Invoke-ATCChatter
			
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

function Get-GroundDistance {
    param (
        [double]$Lat1,
        [double]$Lon1,
        [double]$Lat2,
        [double]$Lon2,
        [double]$Radius
    )

    # convert degrees to radians
    $dLat = ($Lat2 - $Lat1) * [math]::PI / 180
    $dLon = ($Lon2 - $Lon1) * [math]::PI / 180

    # haversine formula
    $sinLat = [math]::Sin($dLat / 2)
    $sinLon = [math]::Sin($dLon / 2)

    $a = [math]::Pow($sinLat, 2) `
       + [math]::Cos($Lat1 * [math]::PI / 180) `
       * [math]::Cos($Lat2 * [math]::PI / 180) `
       * [math]::Pow($sinLon, 2)

    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))

    return $Radius * $c
}

function Get-GroundHeading {
    param ([double]$Lat1, [double]$Lon1, [double]$Lat2, [double]$Lon2)
    $lat1Rad = $Lat1 * [math]::PI / 180
    $lat2Rad = $Lat2 * [math]::PI / 180
    $dLonRad = ($Lon2 - $Lon1) * [math]::PI / 180
    $y = [math]::Sin($dLonRad) * [math]::Cos($lat2Rad)
    $x = [math]::Cos($lat1Rad) * [math]::Sin($lat2Rad) - [math]::Sin($lat1Rad) * [math]::Cos($lat2Rad) * [math]::Cos($dLonRad)
    return ([math]::Atan2($y, $x) * 180 / [math]::PI + 360) % 360
}

function Test-AutopilotReady {
    # Load status
#    $script:StatusPath = Join-Path $inputFolderPath 'Status.json'
    if (-not (Test-Path $script:StatusPath)) { 
		$Global:APInvalidReason = "status.json not found"
		return $false
	}

    try {
#        $status = Get-Content -Path $script:StatusPath -Raw -Encoding ascii | ConvertFrom-Json
        $status = Get-Content $script:StatusPath -Raw | ConvertFrom-Json
    } catch {
        return $false
    }

    # Check docked (bit 1 of Flags)
    if (( $status.Flags -band 0x000001 ) -eq 1) {
		$Global:APInvalidReason = "Ship is docked"
		return $false 
	}

    # Check LAT LON available (bit 21 of Flags)
    if (( $status.Flags -band 0x200000 ) -eq 0) {
		$Global:APInvalidReason = "LAT/LON not present"
		return $false
	}

    # Check critical keys
    if ($null -eq $status.Latitude -or $null -eq $status.Longitude -or $null -eq $status.PlanetRadius) {
		$Global:APInvalidReason = "Critical position info not found (LAT/LON/Radius)"
        return $false
    }

    return $true
}

function Speak-ATCHeading {
    param([double]$Heading)
    $intHead = [int]([math]::Round($Heading))
    $padded  = '{0:000}' -f $intHead
    $spoken  = $padded.ToCharArray() | ForEach-Object {
        switch ($_){
            '9' { 'niner' }
            '0' { 'zero' }
            default { $_ }
        }
    }
    [TTS]::SpeakText("Heading $($spoken -join ' ')")
}

function Invoke-AutopilotTick {
    if (-not $Global:autopilotEnabled) {
        $timer.Stop(); return
    }
#    $script:StatusPath = Join-Path -Path $inputFolderPath -ChildPath "Status.json"
    $localtime = $((Get-Date).ToString('HH:mm:ss'))

	Write-Host "[$localtime] : AutopilotLoop started."	
	
	if (Test-Path $script:StatusPath) {
		try {
#			$status = Get-Content -Path $script:StatusPath -Raw -Encoding ascii | ConvertFrom-Json
			$status = Get-Content $script:StatusPath -Raw | ConvertFrom-Json

#			$hasAltitudeData = ($status.Flags -band 0x20000000) -ne 0

			# Validate planetary surface condition
			if (( $status.Flags -band 0x000001 ) -eq 1) {
				Write-Host "[$localtime] : Autopilot disabled -- ship is docked."
				$Global:autopilotEnabled = $false
				break
			}

#			if (-not $hasAltitudeData) {
#				Write-Host "[$localtime] : Autopilot disabled -- altitude data not present."
#				$Global:autopilotEnabled = $false
#				break
#			}

			# Extract and validate core values
			$currentLat     = $status.Latitude
			$currentLon     = $status.Longitude
			$planetRadius   = $status.PlanetRadius

			if ($null -eq $currentLat -or $null -eq $currentLon -or $null -eq $planetRadius) {
				Write-Host "[$localtime] : Autopilot disabled -- required location data missing (Lat, Lon, or Radius)." -ForegroundColor Red
				$Global:autopilotEnabled = $false
				break
			}

			$distance = Get-GroundDistance -Lat1 $currentLat -Lon1 $currentLon -Lat2 $Global:destLat -Lon2 $Global:destLon -Radius $planetRadius
			$heading  = Get-GroundHeading -Lat1 $currentLat -Lon1 $currentLon -Lat2 $Global:destLat -Lon2 $Global:destLon

			$Global:newdestHeading  = [math]::Round($heading, 2)
			$Global:newdestDistance = [math]::Round($distance, 2)
			
			Write-Host "[$localtime] : Head $Global:newdestHeading, Distance $Global:newdestDistance" -ForegroundColor - Yellow
			
			Compare-And-UpdateVariables

			# --- announce only when tickCount % 3 == 0 ---
			if ($Global:autopilotTickCount % 3 -eq 0) {
				Speak-ATCHeading $Global:newDestHeading
			}

			# increment for next time
			$Global:autopilotTickCount++
			
			if ($distance -le 1000) {
				Write-Host "[$localtime] : Autopilot OFF -- Destination within 1km"
				$Global:autopilotEnabled = $false
				break
			}
		} 
		catch {
			Write-Host "[$localtime] : Autopilot error: $_" -ForegroundColor Red
			$Global:autopilotEnabled = $false
			break
		}
    }
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

$Global:destLat = $null
$Global:destLon = $null
$Global:autopilotEnabled = $false

$Global:destHeading = $null
$Global:newdestHeading = $null
$Global:destDistance = $null
$Global:newdestDistance = $null

$Global:APInvalidReason = "not set"

# Process existing journal file
$first = Get-NewestLogFile
if ($first) { Process-NewLines -filePath $first.FullName }

$Global:autopilotTimer = New-Object System.Timers.Timer 5000
$Global:autopilotTimer.AutoReset = $true
# When the timer elapses, run one tick
$Global:autopilotTimer.Add_Elapsed({ Invoke-AutopilotTick })

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

Write-Host "Monitoring journal (watcher + 500 ms poll)..." -ForegroundColor Yellow
while ($true) { Wait-Event }
