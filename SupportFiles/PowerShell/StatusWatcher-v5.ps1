# v5 - v4 updated after providing chatgpt with actual examples
# Works using ISE but has file join errors if running from a standard PS window

# Set input folder and file
$InputFolder = "D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous"
$FileToMonitor = "status.json"

# Validate folder path
if (-not (Test-Path $InputFolder)) {
    Write-Host "Error: The folder '$InputFolder' does not exist. Exiting." -ForegroundColor Red
    return
}

$FullPath = Join-Path -Path $InputFolder -ChildPath $FileToMonitor
Write-Host "Monitoring file: $FullPath" -ForegroundColor Cyan

# Initialize variables
$GameRunning = $false
$stopMonitoring = $false

# Handle CTRL+C gracefully
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
$watcher.Filter = $FileToMonitor
$watcher.EnableRaisingEvents = $true

# Event handler for file changes
$onChanged = Register-ObjectEvent -InputObject $watcher -EventName Changed -Action {
    if ($stopMonitoring) { return }

    try {
        # Read and parse the JSON file
        $jsonContent = Get-Content -Path $FullPath -Raw | ConvertFrom-Json

        # Extract Flags and Flags2 values
        $FlagsValue = $jsonContent.Flags
        $Flags2Value = if ($jsonContent.PSObject.Properties.Name -contains 'Flags2') { $jsonContent.Flags2 } else { 0 }

        # Determine game status
        if (($FlagsValue -gt 0) -or ($Flags2Value -gt 0)) {
            $GameRunning = $true
            Write-Host "Game is running! Flags or Flags2 detected." -ForegroundColor Green
        } else {
            $GameRunning = $false
            Write-Host "Game is not running. Flags and Flags2 are zero." -ForegroundColor Red
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
