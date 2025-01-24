# chatgpt output for query
# write a powershell script that does the following:
# 1) determine the newest json formatted Journal*.log file within a folder
# 2) read the file line by line 
# 3) look for an entry "Event: Commander" key pair then write a text file containing the string value of a key called "Name:"
# 4) write a text file containing the string value for the latest entry of "event":"Location", "StationName"


# Define the folder where the Journal*.log files are located
$infolderPath = "D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous"
$outfolderPath = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Output"

# Get the newest Journal*.log file
$latestFile = Get-ChildItem -Path $infolderPath -Filter "Journal*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

# Check if a file is found
if ($latestFile) {
    Write-Host "Processing file: $($latestFile.FullName)"
    
    # Initialize variables to store the values
    $commanderName = $null
    $stationName = $null

    # Read the file line by line
    Get-Content -Path $latestFile.FullName | ForEach-Object {
        $line = $_
        
        # Look for "Event: Commander"
        if ($line -match '"Event":\s*"Commander"') {
            # Look for the "Name" key in the same line
            if ($line -match '"Name":\s*"([^"]+)"') {
                $commanderName = $matches[1]
            }
        }
        
        # Look for "event": "Location" and "StationName"
        if ($line -match '"event":\s*"Location"') {
            if ($line -match '"StationName":\s*"([^"]+)"') {
                $stationName = $matches[1]
            }
        }
    }

    # Write the "Name" value to CMDRName.txt if found
    if ($commanderName) {
        $commanderFilePath = "$outfolderPath\CMDRName.txt"
        $commanderName | Out-File -FilePath $commanderFilePath -Encoding UTF8
        Write-Host "Commander Name written to $commanderFilePath"
    } else {
        Write-Host "No 'Commander' event found in the file."
    }

    # Write the "StationName" value for the latest "Docked" event to Station.txt if found
    if ($stationName) {
        $stationFilePath = "$outfolderPath\Station.txt"
        $stationName | Out-File -FilePath $stationFilePath -Encoding UTF8
        Write-Host "Station Name written to $stationFilePath"
    } else {
        Write-Host "No 'Docked' event with 'StationName' found in the file."
    }

} else {
    Write-Host "No Journal*.log file found in the specified folder."
}