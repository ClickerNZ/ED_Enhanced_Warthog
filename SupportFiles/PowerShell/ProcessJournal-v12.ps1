# v11 - Tweak Jornal file detection.

param (
    [string]$inputFolderPath = "D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous",  # Input folder containing the Journal*.log files
    [string]$outputFolderPath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Output"  # Output folder to save the text files
)

# Ensure the output folder exists
if (-not (Test-Path -Path $outputFolderPath)) {
    New-Item -Path $outputFolderPath -ItemType Directory
}

# Function to write to a temporary file and then rename it after completion
function Write-TextToFile {
    param(
        [string]$finalFilePath,
        [string]$content
    )
	Write-Host "Update file $finalFilePath with $content"
    $content | Out-File -FilePath $finalFilePath -Encoding ascii
}

# Function to create placeholder files on script start
function Initialize-PlaceholderFiles {
    Write-Host "Initializing placeholder files..."

    # Define placeholder file names and default content
    $placeholders = @{
        "CMDRName.txt"    = "none"
        "ShipType.txt"    = "none"
        "StationName.txt" = "none"
        "StationType.txt" = "none"
        "ShipName.txt"    = "none"
    }

    # Create placeholder files with default content
    foreach ($file in $placeholders.Keys) {
        $filePath = Join-Path -Path $outputFolderPath -ChildPath $file
        if (-not (Test-Path -Path $filePath)) {
            Write-TextToFile -finalFilePath $filePath -content $placeholders[$file]
        } else {
            Write-Host "Placeholder already exists: $filePath"
        }
    }

}

# Function to find the newest Journal*.log file
function Get-NewestLogFile {
    param(
        [string]$folderPath
    )

    # Get all Journal*.log files and sort by LastWriteTime (most recent first)
    $logFiles = Get-ChildItem -Path $folderPath -Filter "Journal*.log" | Sort-Object LastWriteTime -Descending
    return $logFiles[0]
}

# Function to process the latest Journal*.log file and write to text files
function Process-LatestLogFile {

    if ($latestFile) {
    #    Write-Host "Processing file: $($latestFile.FullName)"
        
        # Initialize variables to store the values
        $loadGameData = @{
            CMDRName  = $null
            ShipType  = $null
        }

        $dockedData = @{
            StationName  = $null
            StationType  = $null
        }
        
        $loadoutData = @{
            ShipName  = $null        
        }
        
        $shipyardswapData = @{
            ShipType  = $null
        }

        $locationData = @{
            StationName  = $null
            StationType  = $null
        }

        $loadGameFound = $false
        $dockedFound = $false
        $loadoutFound = $false
        $shipyardswapFound = $false
        $locationFound = $false
        $shutdownFound = $false

        # Read the file line by line
        Get-Content -Path $latestFile.FullName | ForEach-Object {
            $line = $_

            # Look for the "event: Location" entry
            if ($line -match '"event":\s*"Location"') {
                $locationFound = $true
                if ($line -match '"StationName":\s*"([^"]+)"') {
                    $locationData.StationName = $matches[1]
                }
                if ($line -match '"StationType":\s*"([^"]+)"') {
                    $locationData.StationType = $matches[1]
                }
            }

            # Look for the latest "event: LoadGame" entry
            if ($line -match '"event":\s*"LoadGame"') {
                $loadGameFound = $true
                if ($line -match '"Commander":\s*"([^"]+)"') {
                    $loadGameData.CMDRName = $matches[1]
                }
                if ($line -match '"Ship_Localised":\s*"([^"]+)"') {
                    $loadGameData.ShipType = $matches[1]
                }
            }

            # Look for the latest "event: Docked" entry
            if ($line -match '"event":\s*"Docked"') {
                $dockedFound = $true
                if ($line -match '"StationName":\s*"([^"]+)"') {
                    $dockedData.StationName = $matches[1]
                }
                if ($line -match '"StationType":\s*"([^"]+)"') {
                    $dockedData.StationType = $matches[1]
                }
            }

            # Look for the latest "event: Loadout" entry
            if ($line -match '"event":\s*"Loadout"') {
                $loadoutFound = $true
                if ($line -match '"ShipName":\s*"([^"]+)"') {
                    $loadoutData.ShipName = $matches[1]
                }
            } 

            # Look for the latest "event: ShipyardSwap" entry
            if ($line -match '"event":\s*"ShipyardSwap"') {
                $shipyardswapFound = $true
                if ($line -match '"ShipType_Localised":\s*"([^"]+)"') {
                    $shipyardswapData.ShipType = $matches[1]
                }
            }

            # Check for "event: Shutdown" and exit if found
            if ($line -match '"event":\s*"Shutdown"') {
#                Write-Host "Shutdown event found."
#                $shutdownFound = $true      # disabled until can find a way to only exit after the game has stopped
                return
            }            
        }

        # Process and write extracted data to output files...

        # Write the Location data to output text files (if found)
        if ($locationFound) {
            if ($locationData.StationName) {
                Write-TextToFile -finalFilePath "$outputFolderPath\StationName.txt" -content $locationData.StationName
            }
            if ($locationData.StationType) {
                Write-TextToFile -finalFilePath "$outputFolderPath\StationType.txt" -content $locationData.StationType
            }
        } else {
            Write-Host "No 'Location' event found in the file."
        }

        # Write the LoadGame data to output text files (if found)
        if ($loadGameFound) {
            if ($loadGameData.CMDRName) {
                Write-TextToFile -finalFilePath "$outputFolderPath\CMDRName.txt" -content $loadGameData.CMDRName
            }
            if ($loadGameData.ShipType) {
                Write-TextToFile -finalFilePath "$outputFolderPath\ShipType.txt" -content $loadGameData.ShipType
            }
        } else {
            Write-Host "No 'LoadGame' event found in the file."
        }

        # Write the Docked data to output text files (if found)
        if ($dockedFound) {
            if ($dockedData.StationName) {
                Write-TextToFile -finalFilePath "$outputFolderPath\StationName.txt" -content $dockedData.StationName
            }
            if ($dockedData.StationType) {
                Write-TextToFile -finalFilePath "$outputFolderPath\StationType.txt" -content $dockedData.StationType
            }
        } else {
            Write-Host "No 'Docked' event found in the file."
        }
        
        # Write the Loadout data to output text files (if found)
        if ($loadoutFound) {
            if ($loadoutData.ShipName) {
                Write-TextToFile -finalFilePath "$outputFolderPath\ShipName.txt" -content $loadoutData.ShipName
            }
        } else {
            Write-Host "No 'Loadout' event found in the file."
        }

        # Write the ShipyardSwap data to output text files (if found)
        if ($shipyardswapFound) {
            if ($shipyardswapData.ShipType) {
                Write-TextToFile -finalFilePath "$outputFolderPath\ShipType.txt" -content $shipyardswapData.ShipType
            }
        } else {
            Write-Host "No 'ShipyardSwap' event found in the file."
        }
		
        # If Shutdown event is found, exit the script
        if ($shutdownFound) {
            Write-Host "Exiting due to Shutdown event."
            exit
        }		
		
    } else {
        Write-Host "No Journal*.log file found in the specified folder."
    }
}

# Initialize placeholder files
#Initialize-PlaceholderFiles

# Find the newest Journal*.log file when the script starts
$newestLogFile = Get-NewestLogFile -folderPath $inputFolderPath

# Process the newest log file
Write-Host "Processing the most recent log file: $($newestLogFile.FullName)"
Process-LatestLogFile -logFilePath $newestLogFile.FullName

# Monitor the folder for changes using FileSystemWatcher
$fsWatcher = New-Object System.IO.FileSystemWatcher
$fsWatcher.Path = $inputFolderPath
$fsWatcher.Filter = "Journal*.log"
$fsWatcher.EnableRaisingEvents = $true

# Register event for when a file is created or modified
Register-ObjectEvent -InputObject $fsWatcher -EventName Created -Action {
    $filePath = $EventArgs.FullPath
    Write-Host "New file detected: $filePath"

    # Process the newly created file
    Process-LatestLogFile -logFilePath $filePath
}

Register-ObjectEvent -InputObject $fsWatcher -EventName Changed -Action {
    $filePath = $EventArgs.FullPath
    Write-Host "File changed: $filePath"

    # Process the updated log file
    Process-LatestLogFile -logFilePath $filePath
}

# Keep the script running to monitor the file system
Write-Host "Monitoring folder for changes..."
while ($true) {
#    Start-Sleep -Seconds 10
    Wait-Event  # Wait for events indefinitely
}
