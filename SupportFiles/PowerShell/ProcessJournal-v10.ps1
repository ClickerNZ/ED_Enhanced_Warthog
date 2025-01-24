# v10 - complete rewrite by chatgpt
# v10 - 

# Define folders
$InputFolder = "D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous"
$OutputFolder = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Output"

# Placeholder files and their initial value
$PlaceholderFiles = @(
    "CMDRName.txt",
    "ShipName.txt",
    "ShipType.txt",
    "StationName.txt",
    "StationType.txt",
    "BodyName.txt",
    "SystemName.txt",
    "OrganicFound.txt"
)

# Create output folder if it doesn't exist
if (-not (Test-Path -Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder
}

# Initialize placeholder files
foreach ($file in $PlaceholderFiles) {
    $FilePath = Join-Path $OutputFolder $file
    if (-not (Test-Path -Path $FilePath)) {
        Set-Content -Path $FilePath -Value "none" -Encoding Ascii
    }
}

# Function to update a file if the value has changed
function Update-File {
    param (
        [string]$FilePath,
        [string]$Value
    )
    if ((Get-Content -Path $FilePath -Raw) -ne $Value) {
        $TempFile = "$FilePath.tmp"
        Set-Content -Path $TempFile -Value $Value -Encoding Ascii
        Rename-Item -Path $TempFile -NewName (Split-Path $FilePath -Leaf)
    }
}

# Function to process journal events
function Process-JournalEvent {
    param (
        [hashtable]$EventData
    )

    switch ($EventData.event) {
        "LoadGame" {
            Update-File -FilePath (Join-Path $OutputFolder "CMDRName.txt") -Value $EventData.Commander
            if ($EventData.Ship_Localised) {
                Update-File -FilePath (Join-Path $OutputFolder "ShipType.txt") -Value $EventData.Ship_Localised
            }
        }
        "Docked" {
            Update-File -FilePath (Join-Path $OutputFolder "StationName.txt") -Value $EventData.StationName
            Update-File -FilePath (Join-Path $OutputFolder "StationType.txt") -Value $EventData.StationType
        }
        "Loadout" {
            Update-File -FilePath (Join-Path $OutputFolder "ShipName.txt") -Value $EventData.ShipName
        }
        "ShipyardSwap" {
            Update-File -FilePath (Join-Path $OutputFolder "ShipType.txt") -Value $EventData.ShipType_Localised
        }
        "Location" {
            Update-File -FilePath (Join-Path $OutputFolder "SystemName.txt") -Value $EventData.StarSystem
            Update-File -FilePath (Join-Path $OutputFolder "BodyName.txt") -Value $EventData.Body
            if ($EventData.StationName) {
                Update-File -FilePath (Join-Path $OutputFolder "StationName.txt") -Value $EventData.StationName
            }
            if ($EventData.StationType) {
                Update-File -FilePath (Join-Path $OutputFolder "StationType.txt") -Value $EventData.StationType
            }
        }
        "Touchdown" {
            Update-File -FilePath (Join-Path $OutputFolder "BodyName.txt") -Value $EventData.Body
        }
        "FSDJump" {
            Update-File -FilePath (Join-Path $OutputFolder "SystemName.txt") -Value $EventData.StarSystem
        }
        "ScanOrganic" {
            if ($EventData.Scantype -eq "Analyse") {
                Update-File -FilePath (Join-Path $OutputFolder "OrganicFound.txt") -Value $EventData.Variant_Localised
            }
        }
        "Shutdown" {
            Write-Host "Shutdown event encountered. Exiting script."
            exit
        }
    }
}

# Monitor the input folder for changes
Write-Host "Monitoring folder: $InputFolder"
Get-ChildItem -Path $InputFolder -Filter "Journal*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | ForEach-Object {
    $LastProcessedFile = $_.FullName
}

while ($true) {
    $CurrentFile = Get-ChildItem -Path $InputFolder -Filter "Journal*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($CurrentFile.FullName -ne $LastProcessedFile) {
        $LastProcessedFile = $CurrentFile.FullName
        Write-Host "Processing file: $LastProcessedFile"
    }

    Get-Content -Path $LastProcessedFile | ForEach-Object {
        $EventData = $_ | ConvertFrom-Json
        Process-JournalEvent -EventData $EventData
    }

    Start-Sleep -Seconds 5
}
