# v14 - looks like it might be working.

param (
    [string]$inputFolderPath = "D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous",  # Input folder containing the Journal*.log files
    [string]$outputFolderPath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Output",  # Output folder to save the text files
    [string]$trackingFilePath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Tracking.txt" # File to track the last processed timestamp
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
    try {
        Write-Host "Writing to file: $finalFilePath with content: $content"
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
            Write-Host "Placeholder already exists: $filePath"
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
        Write-Host "Updated last timestamp to: $newTimestamp"
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
    Write-Host "Processing log file: $filePath starting from timestamp: $lastTimestamp"

    try {
        $entries = Get-Content -Path $filePath | ForEach-Object { $_ | ConvertFrom-Json }
        $updatedTimestamp = $lastTimestamp

        foreach ($entry in $entries) {
            if ($null -eq $lastTimestamp -or $entry.timestamp -gt $lastTimestamp) {
                Write-Host "Processing entry with timestamp: $($entry.timestamp)"

                switch ($entry.event) {
                    "Commander" {
                        if ("Name" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "CMDRName.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.Name
                        }
                    }
                    "LoadGame" {
                        if ("Ship_Localised" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "ShipType.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.Ship_Localised
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
                        if ("ShipName" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "ShipName.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.ShipName
                        }
                    }
                    "ShipyardSwap" {
                        if ("ShipType_Localised" -in $entry.PSObject.Properties.Name) {
                            $filePath = Join-Path -Path $outputFolderPath -ChildPath "ShipType.txt"
                            Write-TextToFile -finalFilePath $filePath -content $entry.ShipType_Localised
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

# Main script logic
Initialize-PlaceholderFiles
Process-NewestLogFile

# FileSystemWatcher for real-time monitoring
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $inputFolderPath
$watcher.Filter = "Journal*.log"
$watcher.EnableRaisingEvents = $true
$watcher.IncludeSubdirectories = $false

Register-ObjectEvent -InputObject $watcher -EventName "Changed" -Action {
    param($sender, $eventArgs)
    Write-Host "Detected change in file: $($eventArgs.FullPath)"
    $newestFile = Get-NewestLogFile
    if ($eventArgs.FullPath -eq $newestFile.FullName) {
        $lastTimestamp = Get-LastTimestamp
        Process-LogFile -filePath $newestFile.FullName -lastTimestamp $lastTimestamp
    }
}

Register-ObjectEvent -InputObject $watcher -EventName "Created" -Action {
    param($sender, $eventArgs)
    Write-Host "Detected new file: $($eventArgs.FullPath)"
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

Write-Host "FileSystemWatcher is monitoring $inputFolderPath for changes..."
while ($true) {
#    Start-Sleep -Seconds 10
    Wait-Event  # Wait for events indefinitely
}

