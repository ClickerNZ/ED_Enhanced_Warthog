# v9 - This version includes an initialisation routine to write placeholder text files
# v9 - not working as is. Need to disable the Initialize-Placeholder Files call and bring a whole section from v8 indicated below... 
# v9 - copied section. Files now being written. Console seems to hang though.

param (
    [string]$inputFolderPath = "D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous",  # Input folder containing the Journal*.log files
    [string]$outputFolderPath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Output"  # Output folder to save the text files
)

# Ensure the output folder exists
if (-not (Test-Path -Path $outputFolderPath)) {
    New-Item -Path $outputFolderPath -ItemType Directory
}

# Function to write to a temporary file and then rename it after completion
function Write-TextToTempFile {
    param(
        [string]$finalFilePath,
        [string]$content
    )

    $tempFilePath = "$finalFilePath.tmp"

    # Write content to a temporary file
    $content | Out-File -FilePath $tempFilePath -Encoding ascii

    # Rename the temporary file to the final file
    if (Test-Path -Path $tempFilePath) {
        Rename-Item -Path $tempFilePath -NewName $finalFilePath -Force
        Write-Host "Data written to $finalFilePath"
		Remove-Item -Path $tempFilePath -Force
    }
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
            Write-TextToTempFile -finalFilePath $filePath -content $placeholders[$file]
            Write-Host "Created placeholder: $filePath"
        } else {
            Write-Host "Placeholder already exists: $filePath"
        }
    }
}

# Function to process the latest Journal*.log file and write to text files
function Process-LatestLogFile {
    # Get the newest Journal*.log file from the input folder
    $latestFile = Get-ChildItem -Path $inputFolderPath -Filter "Journal*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($latestFile) {
        Write-Host "Processing file: $($latestFile.FullName)"
        
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

            # Check for "event: Shutdown" and exit if found
            if ($line -match '"event":\s*"Shutdown"') {
                Write-Host "Shutdown event found. Exiting script."
                $shutdownFound = $true
                return
            }

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
        }

        # Process and write extracted data to output files...
        # (existing logic follows here)
# [DM] Good one chatgpt! didn't bother to complete script as requested here it is below, lifted from v8

        # If Shutdown event is found, exit the script
        if ($shutdownFound) {
            Write-Host "Exiting due to Shutdown event."
            exit
        }

        # Write the Location data to output text files (if found)
        if ($locationFound) {
            if ($locationData.StationName) {
                Write-TextToTempFile -finalFilePath "$outputFolderPath\StationName.txt" -content $locationData.StationName
            }
            if ($locationData.StationType) {
                Write-TextToTempFile -finalFilePath "$outputFolderPath\StationType.txt" -content $locationData.StationType
            }
        } else {
            Write-Host "No 'Location' event found in the file."
        }

        # Write the LoadGame data to output text files (if found)
        if ($loadGameFound) {
            if ($loadGameData.CMDRName) {
                Write-TextToTempFile -finalFilePath "$outputFolderPath\CMDRName.txt" -content $loadGameData.CMDRName
            }
            if ($loadGameData.ShipType) {
                Write-TextToTempFile -finalFilePath "$outputFolderPath\ShipType.txt" -content $loadGameData.ShipType
            }
        } else {
            Write-Host "No 'LoadGame' event found in the file."
        }

        # Write the Docked data to output text files (if found)
        if ($dockedFound) {
            if ($dockedData.StationName) {
                Write-TextToTempFile -finalFilePath "$outputFolderPath\StationName.txt" -content $dockedData.StationName
            }
            if ($dockedData.StationType) {
                Write-TextToTempFile -finalFilePath "$outputFolderPath\StationType.txt" -content $dockedData.StationType
            }
        } else {
            Write-Host "No 'Docked' event found in the file."
        }
        
        # Write the Loadout data to output text files (if found)
        if ($loadoutFound) {
            if ($loadoutData.ShipName) {
                Write-TextToTempFile -finalFilePath "$outputFolderPath\ShipName.txt" -content $loadoutData.ShipName
            }
        } else {
            Write-Host "No 'Loadout' event found in the file."
        }

        # Write the ShipyardSwap data to output text files (if found)
        if ($shipyardswapFound) {
            if ($shipyardswapData.ShipType) {
                Write-TextToTempFile -finalFilePath "$outputFolderPath\ShipType.txt" -content $shipyardswapData.ShipType
            }
        } else {
            Write-Host "No 'ShipyardSwap' event found in the file."
        }

    } else {
        Write-Host "No Journal*.log file found in the specified folder."
    }
}

# Initialize placeholder files
#Initialize-PlaceholderFiles # [DM] Disable initialisation call or files won't be written/updated

# Monitor the folder for changes using FileSystemWatcher
$fsWatcher = New-Object System.IO.FileSystemWatcher
$fsWatcher.Path = $inputFolderPath
$fsWatcher.Filter = "Journal*.log"
$fsWatcher.EnableRaisingEvents = $true

# Define the action to take when the file is changed using Register-ObjectEvent
Register-ObjectEvent -InputObject $fsWatcher -EventName Created -Action {
    Write-Host "File created or modified: $($_.FullPath)"
    Process-LatestLogFile
}

Register-ObjectEvent -InputObject $fsWatcher -EventName Changed -Action {
    Write-Host "File created or modified: $($_.FullPath)"
    Process-LatestLogFile
}

# Keep the script running to monitor for file changes indefinitely
Write-Host "Monitoring folder for changes..."
while ($true) {
    Wait-Event  # Wait for events indefinitely
}
