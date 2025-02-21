# v17	- contains importing of external powershell module files to be called via this script
# 			- TTS functions using installed native Windows language voices - works 
#			- Function to lookup external JSON transform lists and return translations for (example) Ship Type - works
#		- Enhance Shutdown event handling - still not working as expected

param (
    [string]$inputFolderPath = "D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous",  # Input folder containing the Journal*.log files
    [string]$outputFolderPath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Output",  # Output folder to save the text files
    [string]$trackingFilePath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Tracking.txt", # File to track the last processed timestamp
	[string]$StatusFile = "status.json" # we check for Flags and Flags2 values and set GameRunning accordingly
)

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

[TTS]::SpeakText("Journal processor loading")

# Load the map file into memory

Import-MapFile -FilePath "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Lookup\EDData.json"

# USAGE:
# $shipvalue = Get-MappedValue -MapName "ShipType_map" -Key "diamondbackxl"
# Write-Output "The value for the key is: $shipvalue"
# USAGE:
#$exovalue = Get-MappedValue -MapName "Exobiology_Value_map" -Key "Aleoida Arcus"
#$formattedNum = $exovalue.ToString("N0")
#Write-Output "The value for the key is: $formattedNum"

Write-Host "ProcessJournal v17"

# Ensure the output folder exists
if (-not (Test-Path -Path $outputFolderPath)) {
    New-Item -Path $outputFolderPath -ItemType Directory
}

# Ensure the tracking file exists
if (-not (Test-Path -Path $trackingFilePath)) {
    Set-Content -Path $trackingFilePath -Value "{\"lastTimestamp\":null}" -Encoding utf8
}

# Function to initialize placeholder files
function Initialize-PlaceholderFiles {
    Write-Host "Initializing placeholder files..."

    $placeholders = @{
        "CMDRName.txt"    = "none"
        "ShipName.txt"    = "none"
        "ShipType.txt"    = "none"
        "StationName.txt" = "none"
        "StationType.txt" = "none"
        "SystemName.txt"  = "none"
        "BodyName.txt"    = "none"
        "OrganicFound.txt" = "none"
    }

    foreach ($file in $placeholders.Keys) {
        $filePath = Join-Path -Path $outputFolderPath -ChildPath $file
        if (-not (Test-Path -Path $filePath)) {
            Write-TextToFile -finalFilePath $filePath -content $placeholders[$file]
        } else {
            Write-Host "Placeholder already exists: $filePath" -ForegroundColor Yellow 
        }
    }
}

# Function to write placeholder files
function Write-TextToFile {
    param(
        [string]$finalFilePath,
        [string]$content
    )

    try {
        Write-Host "Writing to file: $finalFilePath with content: $content" -ForegroundColor Cyan
        $content | Out-File -FilePath $finalFilePath -Encoding ascii
    } catch {
        Write-Host "Error writing to file: $finalFilePath - $_" -ForegroundColor Red
    }
}

# Function to read the tracking file
function Get-LastTimestamp {
    try {
        $trackingData = Get-Content -Path $trackingFilePath | ConvertFrom-Json
        return $trackingData.lastTimestamp
    } catch {
        Write-Host "Error reading tracking file: $_" -ForegroundColor Red
        return $null
    }
}

# Function to update the tracking file
function Update-LastTimestamp {
    param (
        [string]$newTimestamp
    )
    try {
        $trackingData = @{ lastTimestamp = $newTimestamp }
        $trackingData | ConvertTo-Json | Set-Content -Path $trackingFilePath -Encoding utf8
#        Write-Host "Updated last timestamp to: $newTimestamp" -ForegroundColor Yellow
    } catch {
        Write-Host "Error updating tracking file: $_" -ForegroundColor Red
    }
}

# Function to process a single log file
function Process-LogFile {
    param (
        [string]$filePath,
        [string]$lastTimestamp
    )
    #Write-Host "Processing log file: $filePath starting from timestamp: $lastTimestamp" -ForegroundColor Yellow

    try {
        $entries = Get-Content -Path $filePath | ForEach-Object { $_ | ConvertFrom-Json }
        $updatedTimestamp = $lastTimestamp

        foreach ($entry in $entries) {
            if ($null -eq $lastTimestamp -or $entry.timestamp -gt $lastTimestamp) {
                #Write-Host "Processing entry with timestamp: $($entry.timestamp)"

                switch ($entry.event) {
                    "Commander" {
                        if ("Name" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "CMDRName.txt"
                            Write-TextIfDifferent -finalFilePath $filePath -content $entry.Name
                        }
                    }
                    "LoadGame" {
                        if ("Ship" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "ShipType.txt"
							$ShipType = Get-MappedValue -MapName "ShipType_map" -Key $entry.ship 														
                            #Write-TextIfDifferent -finalFilePath $filePath -content $entry.Ship
							Write-TextIfDifferent -finalFilePath $filePath -content $ShipType 
                        }
                    }
                    "Docked" {
                        if ("StationName" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "StationName.txt"
                            Write-TextIfDifferent -finalFilePath $filePath -content $entry.StationName
                        }
                        if ("StationType" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "StationType.txt"
                            Write-TextIfDifferent -finalFilePath $filePath -content $entry.StationType
                        }
                    }
                    "Loadout" {
                        if ("Ship" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "ShipType.txt"
							$ShipType = Get-MappedValue -MapName "ShipType_map" -Key $entry.ship
                            #Write-TextIfDifferent -finalFilePath $filePath -content $entry.Ship
							Write-TextIfDifferent -finalFilePath $filePath -content $ShipType					
                        }
                        if ("ShipName" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "ShipName.txt"
                            Write-TextIfDifferent -finalFilePath $filePath -content $entry.ShipName
                        }
                    }
                    "ShipyardSwap" {
                        if ("ShipType" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "ShipType.txt"
                            #Write-TextIfDifferent -finalFilePath $filePath -content $entry.ShipType
							$ShipType = Get-MappedValue -MapName "ShipType_map" -Key $entry.ShipType  														
							Write-TextIfDifferent -finalFilePath $filePath -content $ShipType 
                        }
                    }
                    "Location" {
                        if ("StarSystem" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "SystemName.txt"
                            Write-TextIfDifferent -finalFilePath $filePath -content $entry.StarSystem
                        }
                        if ("Body" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "BodyName.txt"
                            Write-TextIfDifferent -finalFilePath $filePath -content $entry.Body
                        }
                        if ("StationName" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "StationName.txt"
                            Write-TextIfDifferent -finalFilePath $filePath -content $entry.StationName
                        }
                        if ("StationType" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "StationType.txt"
                            Write-TextIfDifferent -finalFilePath $filePath -content $entry.StationType
                        }
                    }
                    "Touchdown" {
                        if ("Body" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "BodyName.txt"
                            Write-TextIfDifferent -finalFilePath $filePath -content $entry.Body
                        }
                    }
                    "FSDJump" {
                        if ("StarSystem" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "SystemName.txt"
                            Write-TextIfDifferent -finalFilePath $filePath -content $entry.StarSystem
                        }
                    }
                    "ScanOrganic" {
                        if (("ScanType" -in $entry.PSObject.Properties.Name) -and $entry.ScanType -eq "Analyse" -and ("Species_Localised" -in $entry.PSObject.Properties.Name)) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "OrganicFound.txt"
							$exovalue = Get-MappedValue -MapName "Exobiology_Value_map" -Key $entry.Species_Localised
							$formattedNum = [math]::Round($exovalue / 1000000, 1)
							$newSpecies = $entry.Species_Localised 
							if ($Global.GameRunning) {
								Write-TextIfDifferent -finalFilePath $filePath -content $entry.Species_Localised
								[TTS]::SpeakText("Value of $newSpecies is $formattedNum million")
							}
                        }
                    }
					"Shutdown" {
						$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
						Write-Host "[$timestamp] Shutdown event encountered: Game Running is $Global:GameRunning" -ForegroundColor Yellow -BackgroundColor Green
						
						if ($Global:GameRunning) {
							try {
								if ($null -ne $watcher1) {
									$watcher1.Dispose()
									Write-Host "[$timestamp] Watcher1 disposed." -ForegroundColor Green
								}
								if ($null -ne $watcher2) {
									$watcher2.Dispose()
									Write-Host "[$timestamp] Watcher2 disposed." -ForegroundColor Green
								}
							} catch {
								Write-Host "[$timestamp] Error disposing watchers: $_" -ForegroundColor Red
							} finally {
								exit 0
							}
						}
					}
                }

                $updatedTimestamp = $entry.timestamp
            }
        }

        Update-LastTimestamp -newTimestamp $updatedTimestamp
    } catch {
        Write-Host "Error processing log file: $_" -ForegroundColor Red
    }
}

function Write-TextIfDifferent {
    param (
        [string]$finalFilePath,
        [string]$content
    )

    if (Test-Path $finalFilePath) {
        $existingContent = (Get-Content -Path $finalFilePath -Raw).Trim()
        if ($existingContent -eq $content.Trim()) {
            return
        }
    }
    Write-Host "Writing to file: $finalFilePath with content: $content" -ForegroundColor Cyan
    $content | Set-Content -Path $finalFilePath
}

# Function to get the newest log file
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

function Get-KeyValue {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JsonFilePath,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    # Validate that the JSON file exists
    if (-not (Test-Path -Path $JsonFilePath)) {
        throw "The file '$JsonFilePath' does not exist."
    }

    try {
        # Read the JSON file
        $jsonContent = Get-Content -Path $JsonFilePath -Raw | ConvertFrom-Json

        # Attempt to retrieve the value for the specified key
        if ($jsonContent.PSObject.Properties.Name -contains $Key) {
            return $jsonContent.$Key
        } else {
            #throw "The key '$Key' was not found in the JSON file."
			return $false
        }
    } catch {
        throw "An error occurred while processing the JSON file: $_"
    }
}

function Check-GameRunning {
    param (
        [string]$filePath
    )
    Write-Host "Processing status file: $filePath" -ForegroundColor Yellow
    try {
        $Flags = Get-KeyValue -JsonFilePath $filePath -Key "Flags"
        $Flags2 = Get-KeyValue -JsonFilePath $filePath -Key "Flags2"

        if ($Flags2) {
            $Global:GameRunning = $true
        } elseif ($Flags) {
            $Global:GameRunning = $true
        }

        if ($Global:GameRunning) {
            Write-Host "Game is running" -ForegroundColor Green -BackgroundColor Yellow
        } else {
            Write-Host "Game is not running" -ForegroundColor Red -BackgroundColor Yellow
        }
    } catch {
        Write-Host "Error processing file: $_" -ForegroundColor Red
    }
}

# Main script logic
$Global:GameRunning = $false
Initialize-PlaceholderFiles
Process-NewestLogFile

# FileSystemWatcher for real-time monitoring
$watcher1 = New-Object System.IO.FileSystemWatcher
$watcher1.Path = $inputFolderPath
$watcher1.Filter = "Journal*.log"
$watcher1.EnableRaisingEvents = $true
$watcher1.IncludeSubdirectories = $false

Register-ObjectEvent -InputObject $watcher1 -EventName "Changed" -Action {
    param($sender, $eventArgs)
#    Write-Host "Detected change in file: $($eventArgs.FullPath)" -ForegroundColor Yellow 
    $newestFile = Get-NewestLogFile
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
    }
}

$watcher2 = New-Object System.IO.FileSystemWatcher
$watcher2.Path = $inputFolderPath
$watcher2.Filter = "status.json"
$watcher2.EnableRaisingEvents = $true

Register-ObjectEvent -InputObject $watcher2 -EventName "Changed" -Action {
    param($sender, $eventArgs)

    # Debug output to confirm condition
#    Write-Host "Event triggered for file change" -ForegroundColor Cyan
#    Write-Host "Global GameRunning before if: $Global:GameRunning" -ForegroundColor Magenta

    # Ensure the action only runs when $Global:GameRunning is false
    if (-not $Global:GameRunning) {
#        Write-Host "Processing because GameRunning is false" -ForegroundColor Cyan
        $statusFilepath = Join-Path -Path $watcher2.Path -ChildPath $watcher2.Filter
        Check-GameRunning -filePath $statusFilepath
    } else {
#        Write-Host "Skipping processing because GameRunning is true" -ForegroundColor Yellow
    }
}

Write-Host "FileSystemWatcher is monitoring $inputFolderPath for changes..." -ForegroundColor Yellow 
while ($true) {
#    Start-Sleep -Seconds 10
    Wait-Event  # Wait for events indefinitely
}
