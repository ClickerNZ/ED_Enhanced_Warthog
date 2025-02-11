# v19	- Remove text file processing
#		- Use Global variables and a simple flag 
#		- Use Read/Create, Compare, Update json functions

param (
    [string]$inputFolderPath = "D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous",  # Input folder containing the Journal*.log files
    [string]$outputFolderPath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Output",  # Output folder to save the text files
    [string]$trackingFilePath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Tracking.txt", # File to track the last processed timestamp
	[string]$StatusFile = "status.json" # we check for Flags and Flags2 values and set GameRunning accordingly
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
    Set-Content -Path $trackingFilePath -Value "{\"lastTimestamp\":null}" -Encoding ascii
}

# Function 1: Initialize or Load Global Variables from JSON
function Initialize-GlobalVariables {
    if (-Not (Test-Path $JsonFilePath)) {
        # JSON file does not exist, create it with default values
        $defaultData = @{
#			timestamp    = "not set" 
            CMDRName     = "not set"
            ShipName     = "not set"
            ShipType     = "not set"
            StationName  = "not set"
            StationType  = "not set"
            SystemName   = "not set"
            BodyName     = "not set"
            OrganicFound = "not set"
        }
        $defaultData | ConvertTo-Json | Set-Content $JsonFilePath
    }

    # Read JSON file and parse data
    $jsonData = Get-Content $JsonFilePath | ConvertFrom-Json

    # Assign global variables
#   $Global:timestamp = $jsonData.timestamp
    $Global:CMDRName = $jsonData.CMDRName
    $Global:ShipName = $jsonData.ShipName
    $Global:ShipType = $jsonData.ShipType
    $Global:StationName = $jsonData.StationName
    $Global:StationType = $jsonData.StationType
    $Global:SystemName = $jsonData.SystemName
    $Global:BodyName = $jsonData.BodyName
    $Global:OrganicFound = $jsonData.OrganicFound
}

# Function 2: Compare New Variables with Global Variables
function Compare-And-UpdateVariables {
    $changeDetected = $false

    # List of tracked keys
    $keys = @("CMDRName", "ShipName", "ShipType", "StationName", "StationType", "SystemName", "BodyName", "OrganicFound")

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

    if ($changeDetected) {
        foreach ($key in $keys) {
            $newKeyName = "Global:new$key"
            $globalKeyName = "Global:$key"

            if (Test-Path Variable:$newKeyName) {
                Set-Variable -Name $key -Value (Get-Variable -Name "new$key" -Scope Global).Value -Scope Global
            }
        }
		Write-Host "Update MyJournalData.json" -ForegroundColor Cyan
        Update-JsonFile
    }
}

# Function 3: Update JSON File
function Update-JsonFile {
	
	$Global:timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
	
    $updatedData = [ordered]@{
        timestamp    = $Global:timestamp			
        CMDRName     = $Global:CMDRName
        ShipName     = $Global:ShipName
        ShipType     = $Global:ShipType
        StationName  = $Global:StationName
        StationType  = $Global:StationType
        SystemName   = $Global:SystemName
        BodyName     = $Global:BodyName
        OrganicFound = $Global:OrganicFound
    }

    $updatedData | ConvertTo-Json -Compress | Set-Content $JsonFilePath
   # Convert to JSON without whitespace
#    $jsonString = $updatedData | ConvertTo-Json -Compress
#    Set-Content -Path $JsonFilePath -Value $jsonString
}

<#
# Function to initialize placeholder files
function Initialize-PlaceholderFiles {
    Write-Host "Initializing placeholder files..."

    $placeholders = @{
        "CMDRName.txt" = "none"
        "ShipName.txt" = "none"
        "ShipType.txt" = "none"
        "StationName.txt" = "none"
        "StationType.txt" = "none"
        "SystemName.txt" = "none"
        "BodyName.txt" = "none"
        "OrganicFound.txt" = "none"
    }

    foreach ($file in $placeholders.Keys) {
        $filePath = Join-Path -Path $outputFolderPath -ChildPath $file
        if (-not (Test-Path -Path $filePath)) {
            Write-TextToFile -finalFilePath $filePath -content $placeholders[$file]
        } else {
        #    Write-Host "Placeholder already exists: $filePath" -ForegroundColor Yellow 
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
    #    Write-Host "Writing to file: $finalFilePath with content: $content" -ForegroundColor Cyan
        $content | Out-File -FilePath $finalFilePath -Encoding ascii
    } catch {
        Write-Host "Error writing to file: $finalFilePath - $_" -ForegroundColor Red
    }
}
#>

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
        $trackingData | ConvertTo-Json | Set-Content -Path $trackingFilePath -Encoding ascii
#        Write-Host "Updated last timestamp to: $newTimestamp" -ForegroundColor Yellow
    } catch {
        Write-Host "Error updating tracking file: $_" -ForegroundColor Red
    }
}

<#
# Add function to update MyJournalData.json
function Update-MyJournalData {
    param (
        [string]$outputFolderPath,
        [string]$filePath,
        [string]$fileContent,
        [string]$timestamp
    )
    
    $jsonFilePath = Join-Path -Path $outputFolderPath -ChildPath "MyJournalData.json"
    
    # Define required keys with default empty values
    $defaultKeys = @{
        "timestamp" = "";
        "CMDRName" = "";
        "ShipType" = "";
        "ShipName" = "";
        "StationName" = "";
        "StationType" = "";
        "SystemName" = "";
        "BodyName" = "";
        "OrganicFound" = "";
    }
    
    # Load existing JSON data manually as a hashtable
    if (Test-Path $jsonFilePath) {
        $jsonData = Get-Content $jsonFilePath -Raw | ConvertFrom-Json
        
        # Convert from PSCustomObject to Hashtable if necessary
        if ($jsonData -isnot [hashtable]) {
            $newJsonData = @{}
            foreach ($property in $jsonData.PSObject.Properties) {
                $newJsonData[$property.Name] = $property.Value
            }
            $jsonData = $newJsonData
        }
    } else {
        $jsonData = $defaultKeys.Clone()
    }
    
    # Ensure JSON data includes all required keys
    foreach ($key in $defaultKeys.Keys) {
        if (-not $jsonData.ContainsKey($key)) {
            $jsonData[$key] = $defaultKeys[$key]
        }
    }
    
    # Update the timestamp
    $jsonData["timestamp"] = $timestamp
    
    # Extract base filename and ensure it's valid
    $baseFileName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
    if ($baseFileName -and ($baseFileName -ne "")) {
        # Ensure key comparison is case-insensitive
        $matchingKey = ($defaultKeys.Keys | Where-Object { $_ -ieq $baseFileName })
        if ($matchingKey) {
            $jsonData[$matchingKey] = $fileContent
        } else {
            Write-Warning "Key $baseFileName does not exist in predefined keys. Skipping update."
        }
    } else {
        Write-Warning "Invalid base file name extracted from path: $filePath"
    }
    
    # Save back to JSON file, preserving all entries
    $jsonData | ConvertTo-Json -Depth 10 -Compress | Set-Content -Path $jsonFilePath -Encoding ascii
}
#>

# Function to process a single log file
function Process-LogFile {
    param (
        [string]$filePath,
        [string]$lastTimestamp
    )
    #Write-Host "Processing log file: $filePath starting from timestamp: $lastTimestamp" -ForegroundColor Yellow

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"  # Match log file timestamp format

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
#						    $textFileName = "CMDRName.txt"
#							$textContent = $entry.Name
#						    $filePath = Join-Path -Path $outputFolderPath -ChildPath $textFileName
#							Write-TextIfDifferent -finalFilePath $filePath -content $textContent
#						    Update-MyJournalData -outputFolderPath $outputFolderPath -filePath $filePath -fileContent $textContent -timestamp $timestamp
#							Write-Host "Update MyJournal.json: Key = CMDRName, Value = $textContent" -ForegroundColor Cyan
                        }
                    }
                    "LoadGame" {
                        if ("Ship" -in $entry.PSObject.Properties.Name) {
 							$ShipType = Get-MappedValue -MapName "ShipType_map" -Key $entry.ship
							$Global:newShipType = $ShipType
#						    $textFileName = "ShipType.txt"
#							$textContent = $ShipType
#						    $filePath = Join-Path -Path $outputFolderPath -ChildPath $textFileName
#							Write-TextIfDifferent -finalFilePath $filePath -content $textContent
#						    Update-MyJournalData -outputFolderPath $outputFolderPath -filePath $filePath -fileContent $textContent -timestamp $timestamp
#							Write-Host "Update MyJournal.json: Key = ShipType, Value = $textContent" -ForegroundColor Cyan
                        }
                    }
					"DockingGranted" {
                        if ("StationName" -in $entry.PSObject.Properties.Name) {
							$Global:newStationName = $entry.StationName
						}
                        if ("StationType" -in $entry.PSObject.Properties.Name) {
							$Global:newStationType = $entry.StationType
						}
					}
					
                    "Docked" {
                        if ("StationName" -in $entry.PSObject.Properties.Name) {
							$Global:newStationName = $entry.StationName
#						    $textFileName = "StationName.txt"
#							$textContent = $entry.StationName
#						    $filePath = Join-Path -Path $outputFolderPath -ChildPath $textFileName
#							Write-TextIfDifferent -finalFilePath $filePath -content $textContent
#						    Update-MyJournalData -outputFolderPath $outputFolderPath -filePath $filePath -fileContent $textContent -timestamp $timestamp
#							Write-Host "Update MyJournal.json: Key = StationName, Value = $textContent" -ForegroundColor Cyan
                        }
                        if ("StationType" -in $entry.PSObject.Properties.Name) {
							$Global:newStationType = $entry.StationType
#						    $textFileName = "StationType.txt"
#							$textContent = $entry.StationType
#						    $filePath = Join-Path -Path $outputFolderPath -ChildPath $textFileName
#							Write-TextIfDifferent -finalFilePath $filePath -content $textContent
#						    Update-MyJournalData -outputFolderPath $outputFolderPath -filePath $filePath -fileContent $textContent -timestamp $timestamp												
#							Write-Host "Update MyJournal.json: Key = StationType, Value = $textContent" -ForegroundColor Cyan
                        }
                    }
                    "Loadout" {
                        if ("Ship" -in $entry.PSObject.Properties.Name) {
							$ShipType = Get-MappedValue -MapName "ShipType_map" -Key $entry.ship
							$Global:newShipType = $ShipType
#						    $textFileName = "ShipType.txt"
#							$textContent = $ShipType
#						    $filePath = Join-Path -Path $outputFolderPath -ChildPath $textFileName
#							Write-TextIfDifferent -finalFilePath $filePath -content $textContent
#						    Update-MyJournalData -outputFolderPath $outputFolderPath -filePath $filePath -fileContent $textContent -timestamp $timestamp
#							Write-Host "Update MyJournal.json: Key = ShipType, Value = $textContent" -ForegroundColor Cyan
                        }
                        if ("ShipName" -in $entry.PSObject.Properties.Name) {
							$Global:newShipName = $entry.ShipName
#						    $textFileName = "ShipName.txt"
#							$textContent = $entry.ShipName
#						    $filePath = Join-Path -Path $outputFolderPath -ChildPath $textFileName
#							Write-TextIfDifferent -finalFilePath $filePath -content $textContent
#						    Update-MyJournalData -outputFolderPath $outputFolderPath -filePath $filePath -fileContent $textContent -timestamp $timestamp
#							Write-Host "Update MyJournal.json: Key = ShipName, Value = $textContent" -ForegroundColor Cyan
                        }
                    }
                    "ShipyardSwap" {
                        if ("ShipType" -in $entry.PSObject.Properties.Name) {
							$ShipType = Get-MappedValue -MapName "ShipType_map" -Key $entry.ship
							$Global:newShipType = $ShipType
#						    $textFileName = "ShipType.txt"
#							$textContent = $ShipType
#						    $filePath = Join-Path -Path $outputFolderPath -ChildPath $textFileName
#							Write-TextIfDifferent -finalFilePath $filePath -content $textContent
#						    Update-MyJournalData -outputFolderPath $outputFolderPath -filePath $filePath -fileContent $textContent -timestamp $timestamp
#							Write-Host "Update MyJournal.json: Key = ShipType, Value = $textContent" -ForegroundColor Cyan
                        }
                    }
                    "Location" {
                        if ("StarSystem" -in $entry.PSObject.Properties.Name) {
							$Global:newSystemName = $entry.StarSystem
#						    $textFileName = "SystemName.txt"
#							$textContent = $entry.StarSystem
#						    $filePath = Join-Path -Path $outputFolderPath -ChildPath $textFileName
#							Write-TextIfDifferent -finalFilePath $filePath -content $textContent
#						    Update-MyJournalData -outputFolderPath $outputFolderPath -filePath $filePath -fileContent $textContent -timestamp $timestamp
#							Write-Host "Update MyJournal.json: Key = SystemName, Value = $textContent" -ForegroundColor Cyan
                        }
                        if ("Body" -in $entry.PSObject.Properties.Name) {
							$Global:newBodyName = $entry.Body
#						    $textFileName = "BodyName.txt"
#							$textContent = $entry.Body
#						    $filePath = Join-Path -Path $outputFolderPath -ChildPath $textFileName
#							Write-TextIfDifferent -finalFilePath $filePath -content $textContent
#						    Update-MyJournalData -outputFolderPath $outputFolderPath -filePath $filePath -fileContent $textContent -timestamp $timestamp
#							Write-Host "Update MyJournal.json: Key = BodyName, Value = $textContent" -ForegroundColor Cyan
                        }
                        if ("StationName" -in $entry.PSObject.Properties.Name) {
							$Global:newStationName = $entry.StationName
#						    $textFileName = "StationName.txt"
#							$textContent = $entry.StationName
#						    $filePath = Join-Path -Path $outputFolderPath -ChildPath $textFileName
#							Write-TextIfDifferent -finalFilePath $filePath -content $textContent
#						    Update-MyJournalData -outputFolderPath $outputFolderPath -filePath $filePath -fileContent $textContent -timestamp $timestamp
#							Write-Host "Update MyJournal.json: Key = StationName, Value = $textContent" -ForegroundColor Cyan
                        }
                        if ("StationType" -in $entry.PSObject.Properties.Name) {
							$Global:newStationType = $entry.StationType
#						    $textFileName = "SystemType.txt"
#							$textContent = $entry.StationType
#						    $filePath = Join-Path -Path $outputFolderPath -ChildPath $textFileName
#							Write-TextIfDifferent -finalFilePath $filePath -content $textContent
#						    Update-MyJournalData -outputFolderPath $outputFolderPath -filePath $filePath -fileContent $textContent -timestamp $timestamp
#							Write-Host "Update MyJournal.json: Key = SystemType, Value = $textContent" -ForegroundColor Cyan
                        }
                    }
                    "Touchdown" {
                        if ("Body" -in $entry.PSObject.Properties.Name) {
							$Global:newBodyName = $entry.Body
#						    $textFileName = "BodyName.txt"
#							$textContent = $entry.Body
#						    $filePath = Join-Path -Path $outputFolderPath -ChildPath $textFileName
#							Write-TextIfDifferent -finalFilePath $filePath -content $textContent
#						    Update-MyJournalData -outputFolderPath $outputFolderPath -filePath $filePath -fileContent $textContent -timestamp $timestamp
#							Write-Host "Update MyJournal.json: Key = BodyName, Value = $textContent" -ForegroundColor Cyan
                        }
                    }
                    "FSDJump" {
                        if ("StarSystem" -in $entry.PSObject.Properties.Name) {
							$Global:newSystemName = $entry.StarSystem
#						    $textFileName = "SystemName.txt"
#							$textContent = $entry.StarSystem
#						    $filePath = Join-Path -Path $outputFolderPath -ChildPath $textFileName
#							Write-TextIfDifferent -finalFilePath $filePath -content $textContent
#						    Update-MyJournalData -outputFolderPath $outputFolderPath -filePath $filePath -fileContent $textContent -timestamp $timestamp
#							Write-Host "Update MyJournal.json: Key = SystemName, Value = $textContent" -ForegroundColor Cyan
                        }
                    }
                    "ScanOrganic" {						
                        if (("ScanType" -in $entry.PSObject.Properties.Name) -and $entry.ScanType -eq "Analyse" -and ("Species_Localised" -in $entry.PSObject.Properties.Name)) {
							if ($Global.GameRunning) { 								
								$exovalue = Get-MappedValue -MapName "Exobiology_Value_map" -Key $entry.Species_Localised
								$formattedNum = [math]::Round($exovalue / 1000000, 1)
								$Global:newOrganicFound = $entry.Species_Localised
								[TTS]::SpeakText("Value of $Global:newOrganicFound is $formattedNum million")
							}
#							$newSpecies = $entry.Species_Localised
#						    $textFileName = "OrganicFound.txt"
#							$textContent = $newSpecies
#						    $filePath = Join-Path -Path $outputFolderPath -ChildPath $textFileName							
						#	if ($Global.GameRunning) { 
#								Write-TextIfDifferent -finalFilePath $filePath -content $textContent
#								Update-MyJournalData -outputFolderPath $outputFolderPath -filePath $filePath -fileContent $textContent -timestamp $timestamp
#								Write-Host "Update MyJournal.json: Key = OrganicFound, Value = $textContent" -ForegroundColor Cyan
#								[TTS]::SpeakText("Value of $newSpecies is $formattedNum million")							
						#	}
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
		
		Compare-And-UpdateVariables			# Compares Global:newKeyValues with Global:KeyValues and updates MyJournalData.json
		
    } catch {
        Write-Host "Error processing log file: $_" -ForegroundColor Red
    }
}

<#
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
#>

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

<#
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
#>

<#
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
#>

#####################
# Main script logic #
#####################

#Define Global variables 
$Global:GameRunning = $false

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
#$Global:newtimestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Process-NewestLogFile

# FileSystemWatcher for real-time monitoring
$watcher1 = New-Object System.IO.FileSystemWatcher
$watcher1.Path = $inputFolderPath
$watcher1.Filter = "Journal*.log"
$watcher1.EnableRaisingEvents = $true
$watcher1.IncludeSubdirectories = $false

Register-ObjectEvent -InputObject $watcher1 -EventName "Changed" -Action {
    param($sender, $eventArgs)
    #Write-Host "Detected change in file: $($eventArgs.FullPath)" -ForegroundColor Yellow 
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
		$Global:GameRunning = $true 
		Write-Host "Game is running" -ForegroundColor Green -BackgroundColor Yellow
    }
}

<#
$watcher2 = New-Object System.IO.FileSystemWatcher
$watcher2.Path = $inputFolderPath
$watcher2.Filter = "status.json"
$watcher2.EnableRaisingEvents = $true

Register-ObjectEvent -InputObject $watcher2 -EventName "Changed" -Action {
    param($sender, $eventArgs)

    # Ensure the action only runs when $Global:GameRunning is false
    if (-not $Global:GameRunning) {
        $statusFilepath = Join-Path -Path $watcher2.Path -ChildPath $watcher2.Filter
        Check-GameRunning -filePath $statusFilepath
    } else {
        #Write-Host "Skipping processing because GameRunning is true" -ForegroundColor Yellow
    }
}
#>

Write-Host "FileSystemWatcher is monitoring $inputFolderPath for changes..." -ForegroundColor Yellow 
while ($true) {
    Wait-Event  # Wait for events indefinitely
}
