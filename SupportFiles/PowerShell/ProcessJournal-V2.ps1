# chatgpt output for query
# write a powershell script that does the following:
# 1) determine the newest json formatted Journal*.log file within a folder
# 2) read the file line by line 
# 3) look for an entry "Event: Commander" key pair then write a text file containing the string value of a key called "Name:"
# 4) write a text file containing the string value for the latest entry of "event":"Docked", "StationName"
# 5) use - Encoding ascii to avoid writing file BOM that powershell uses for Encoding = utf8 (lowercase utf8 does not work)

param (
    [string]$inputFolderPath =  "D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous",  # Input folder containing the Journal*.log files
    [string]$outputFolderPath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Output" # Output folder to save the text files
)

# Ensure the output folder exists
if (-not (Test-Path -Path $outputFolderPath)) {
    New-Item -Path $outputFolderPath -ItemType Directory
}

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

    $loadGameFound = $false
    $dockedFound = $false
	$loadoutFound = $false

    # Read the file line by line
    Get-Content -Path $latestFile.FullName | ForEach-Object {
        $line = $_
        
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
        if ($loadGameData.ShipName) {
            $loadGameData.ShipName | Out-File -FilePath "$outputFolderPath\ShipName.txt" -Encoding ascii
            Write-Host "ShipName written to ShipName.txt"
        }
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
        Write-Host "No 'LoadGame' event found in the file."
    }
	
} else {
    Write-Host "No Journal*.log file found in the specified folder."
}
