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
    Stop-Transcript
}
trap {
    Write-Host "CTRL+C detected. Exiting..."
    $stopMonitoring = $true
    Stop-Transcript
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
        $jsonContent = Get-Content -Path $FullPath -Raw | ConvertFrom-Json
        if (($jsonContent.Flags -gt 0) -or ($jsonContent.Flags2 -gt 0)) {
            $GameRunning = $true
            Write-Host "Game is running! Flags detected." -ForegroundColor Green
        } else {
            $GameRunning = $false
            Write-Host "Game is not running. Flags not detected." -ForegroundColor Red
        }
    } catch {
        Write-Host "Error reading or processing JSON file." -ForegroundColor Yellow
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
