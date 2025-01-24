# v2 - Powershell version 7+ compliant

# Set input folder and file
$InputFolder = "D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous"
$FileToMonitor = "status.json"
$FullPath = Join-Path -Path $InputFolder -ChildPath $FileToMonitor

# Initialize variables
$GameRunning = $false

# Function to handle CTRL+C gracefully
$stopMonitoring = $false
$handler = {
    Write-Host "Exiting script..."
    $stopMonitoring = $true
}

trap {
    Write-Host "CTRL+C detected. Exiting..."
    $stopMonitoring = $true
}

# Wait until the file exists
while (-not (Test-Path $FullPath)) {
    if ($stopMonitoring) { break }
    Write-Host "Waiting for file: $FullPath" -ForegroundColor Yellow
    Start-Sleep -Seconds 10
}
if ($stopMonitoring) { return }

Write-Host "File found! Monitoring file changes..." -ForegroundColor Green

# Create a FileSystemWatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $InputFolder
$watcher.Filter = "status.json"
$watcher.EnableRaisingEvents = $true

# Event handlers
$onChanged = Register-ObjectEvent -InputObject $watcher -EventName Changed -Action {
    if ($stopMonitoring) { return }

    try {
        # Read and parse the JSON file
        $jsonContent = Get-Content -Path $FullPath -Raw | ConvertFrom-Json
        
        # Check if Flags key exists and process accordingly
        if ($null -ne $jsonContent.Flags) {
            $FlagsValue = $jsonContent.Flags
            $Flags2Value = $jsonContent.PSObject.Properties['Flags2']?.Value

            # Determine game status
            if (($FlagsValue -gt 0) -or ($Flags2Value -gt 0)) {
                $GameRunning = $true
                Write-Host "Game is running! Flags detected." -ForegroundColor Green
            } else {
                $GameRunning = $false
                Write-Host "Game is not running. Flags not detected." -ForegroundColor Red
            }
        } else {
            Write-Host "Error: 'Flags' key is missing from JSON. This should not occur." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error reading or processing JSON file: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Wait for CTRL+C to exit
try {
    while (-not $stopMonitoring) {
        Start-Sleep -Seconds 1
    }
} finally {
    # Clean up
    Unregister-Event -SourceIdentifier $onChanged.Name
    $watcher.Dispose()
    Write-Host "Monitoring stopped. Script exited." -ForegroundColor Cyan
}
