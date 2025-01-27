# v15 - tweaked v14.
# Change ShipType logic to use map table.

param (
    [string]$inputFolderPath = "D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous",  # Input folder containing the Journal*.log files
    [string]$outputFolderPath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Output",  # Output folder to save the text files
    [string]$trackingFilePath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Tracking.txt", # File to track the last processed timestamp
	[string]$StatusFile = "status.json" # we check for Flags and Flags2 values and set GameRunning accordingly
)

# Ensure the output folder exists
if (-not (Test-Path -Path $outputFolderPath)) {
    New-Item -Path $outputFolderPath -ItemType Directory
}

# Ensure the tracking file exists
if (-not (Test-Path -Path $trackingFilePath)) {
    Set-Content -Path $trackingFilePath -Value "{\"lastTimestamp\":null}" -Encoding utf8
}

# Function to write to a temporary file and then rename it after completion
function Write-TextToFile {
    param(
        [string]$finalFilePath,
        [string]$content
    )

# the write-texttotempfile was causing issues. keep the old code if we wish to re-implement
#    $tempFilePath = "$finalFilePath.tmp"

    # Write content to a temporary file
#    $content | Out-File -FilePath $tempFilePath -Encoding ascii   # don't write temp file

    # Rename the temporary file to the final file
#    if (Test-Path -Path $tempFilePath) {
#        Rename-Item -Path $tempFilePath -NewName $finalFilePath -Force
#        Write-Host "Data written to $finalFilePath"
#        Remove-Item -Path $tempFilePath -Force
#    }

# do this instead

    try {
        Write-Host "Writing to file: $finalFilePath with content: $content" -ForegroundColor Cyan
        $content | Out-File -FilePath $finalFilePath -Encoding ascii
    } catch {
        Write-Host "Error writing to file: $finalFilePath - $_" -ForegroundColor Red
    }
}

# Function to initialize placeholder files
function Initialize-PlaceholderFiles {
    Write-Host "Initializing placeholder files..."

    $placeholders = @{
        "CMDRName.txt"    = "none"
        "ShipType.txt"    = "none"
        "StationName.txt" = "none"
        "StationType.txt" = "none"
        "ShipName.txt"    = "none"
        "BodyName.txt"    = "none"
        "SystemName.txt"  = "none"
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
        Write-Host "Updated last timestamp to: $newTimestamp" -ForegroundColor Yellow
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
    #Write-Host "Processing log file: $filePath starting from timestamp: $lastTimestamp"

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
                            Write-TextToFile -finalFilePath $filePath -content $entry.Name
                        }
                    }
                    "LoadGame" {
                        if ("Ship" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "ShipType.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.Ship
                        }
                    }
                    "Docked" {
                        if ("StationName" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "StationName.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.StationName
                        }
                        if ("StationType" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "StationType.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.StationType
                        }
                    }
                    "Loadout" {
                        if ("Ship" -in $entry.PSObject.Properties.Name) {
							#Lookup-Shiptype -ship $entry.ship 
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "ShipType.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.Ship
                        }
                        if ("ShipName" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "ShipName.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.ShipName
                        }
                    }
                    "ShipyardSwap" {
                        if ("ShipType" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "ShipType.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.ShipType
                        }
                    }
                    "Location" {
                        if ("StarSystem" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "SystemName.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.StarSystem
                        }
                        if ("Body" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "BodyName.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.Body
                        }
                        if ("StationName" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "StationName.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.StationName
                        }
                        if ("StationType" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "StationType.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.StationType
                        }
                    }
                    "Touchdown" {
                        if ("Body" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "BodyName.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.Body
                        }
                    }
                    "FSDJump" {
                        if ("StarSystem" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "SystemName.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.StarSystem
                        }
                    }
                    "ScanOrganic" {
                        if (("ScanType" -in $entry.PSObject.Properties.Name) -and $entry.ScanType -eq "Analyse" -and ("Variant_Localised" -in $entry.PSObject.Properties.Name)) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "OrganicFound.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.Variant_Localised
                        }
                    }
					"Shutdown" {
						Write-Host "Shutdown event encountered: Game Running is $GameRunning" -ForegroundColor Yellow -BackgroundColor Green
						if ($GameRunning) {
							#Write-Host "Exiting due to Shutdown event." -ForegroundColor Yellow -BackgroundColor Green
							# Cleanup watchers on exit 
							$watcher1.Dispose()
							$watcher2.Dispose()
							exit
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
	
	#Write-Host "Processing status file: $filePath" -ForegroundColor Yellow 	
	$Flags = Get-KeyValue -JsonFilePath $filePath -Key "Flags"	
	$Flags2 = Get-KeyValue -JsonFilePath $filePath -Key "Flags2"	

	if ($Flags2) {
		$GameRunning = $true
	}
	else {
		if ($Flags) {
			$GameRunning = $true
		}
	}
	# Should only trigger once...
	if ($GameRunning){
		Write-Host "Game is running" -ForegroundColor Green -BackgroundColor Yellow
	}
	# Should never see this...
	else {
		Write-Host "Game is not running" -ForegroundColor Red -BackgroundColor Yellow
	}
}

# Main script logic
$GameRunning = $false
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
    Write-Host "Detected change in file: $($eventArgs.FullPath)" -ForegroundColor Yellow 
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
            Write-Host "Error processing new log file: $_" -ForegroundColor Red
        }
    }
}

$watcher2 = New-Object System.IO.FileSystemWatcher
$watcher2.Path = $inputFolderPath
$watcher2.Filter = "status.json"
$watcher2.EnableRaisingEvents = $true

Register-ObjectEvent -InputObject $watcher2 -EventName "Changed" -Action {
	if (-not $GameRunning) {	
		param($sender, $eventArgs)
		Write-Host "Detected change in file: $($eventArgs.FullPath)" -ForegroundColor Yellow 
		$statusFilepath = Join-Path -Path $watcher2.Path -ChildPath $watcher2.Filter   
		Check-GameRunning -filePath $statusFilepath	
	}
}

Write-Host "FileSystemWatcher is monitoring $inputFolderPath for changes..." -ForegroundColor Yellow 
while ($true) {
#    Start-Sleep -Seconds 10
    Wait-Event  # Wait for events indefinitely
}

