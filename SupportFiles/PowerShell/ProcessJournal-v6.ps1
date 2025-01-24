# This version continuously monitors for updates and changes rather than periodically

param (
    [string]$inputFolderPath = "D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous",  # Input folder containing the Journal*.log files
    [string]$outputFolderPath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Output"  # Output folder to save the text files
)

# Ensure the output folder exists
if (-not (Test-Path -Path $outputFolderPath)) {
    New-Item -Path $outputFolderPath -ItemType Directory
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

        $loadGameFound = $false
        $dockedFound = $false
        $loadoutFound = $false
		$shipyardswapFound = $false
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

        # If Shutdown event is found, exit the script
        if ($shutdownFound) {
            Write-Host "Exiting due to Shutdown event."
            exit
        }

        # Write the data to output text files
        if ($loadGameFound) {
            if ($loadGameData.CMDRName) {
                $loadGameData.CMDRName | Out-File -FilePath "$outputFolderPath\CMDRName.txt" -Encoding ascii
                Write-Host "CMDRName written to CMDRName.txt"
            }
            if ($loadGameData.ShipType) {
                $loadGameData.ShipType | Out-File -FilePath "$outputFolderPath\ShipType.txt" -Encoding ascii
                Write-Host "ShipType written to ShipType.txt"
            }
			 # Don't use this as the name may be obfuscated
#            if ($loadoutData.ShipName) {
#                $loadoutData.ShipName | Out-File -FilePath "$outputFolderPath\ShipName.txt" -Encoding ascii
#                Write-Host "ShipName written to ShipName.txt"
#            }
        } else {
            Write-Host "No 'LoadGame' event found in the file."
        }

        if ($dockedFound) {
            if ($dockedData.StationName) {
                $dockedData.StationName | Out-File -FilePath "$outputFolderPath\StationName.txt" -Encoding ascii
                Write-Host "StationName written to StationName.txt"
            }
            if ($dockedData.StationType) {
                $dockedData.StationType | Out-File -FilePath "$outputFolderPath\StationType.txt" -Encoding ascii
                Write-Host "StationType written to StationType.txt"
            }
        } else {
            Write-Host "No 'Docked' event found in the file."
        }
        
        if ($loadoutFound) {
            if ($loadoutData.ShipName) {
                $loadoutData.ShipName | Out-File -FilePath "$outputFolderPath\ShipName.txt" -Encoding ascii
                Write-Host "ShipName written to ShipName.txt"
            }
        } else {
            Write-Host "No 'Loadout' event found in the file."
        }

        if ($shipyardswapFound) {
            if ($shipyardswapData.ShipType) {
                $shipyardswapData.ShipType | Out-File -FilePath "$outputFolderPath\ShipType.txt" -Encoding ascii
                Write-Host "ShipType written to ShipName.txt"
            }
        } else {
            Write-Host "No 'ShipyardSwap' event found in the file."
        }

    } else {
        Write-Host "No Journal*.log file found in the specified folder."
    }
}

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
