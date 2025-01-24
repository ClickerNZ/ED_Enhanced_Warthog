# v12 - going in circles!

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

# Function to check the current game state
function Check-GameState {
    param (
        [string]$FilePath
    )
    if (-not (Test-Path $FilePath)) {
        Write-Host "File '$FilePath' does not exist. Assuming game is not running." -ForegroundColor Yellow
        return $false
    }

    try {
        $jsonContent = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
        $FlagsValue = $jsonContent.Flags
        $Flags2Value = if ($jsonContent.PSObject.Properties.Name -contains 'Flags2') { $jsonContent.Flags2 } else { 0 }

        if (($FlagsValue -gt 0) -or ($Flags2Value -gt 0)) {
            Write-Host "Game is currently running! Flags detected." -ForegroundColor Green
            return $true
        } else {
            Write-Host "Game is not running. Flags and Flags2 are zero." -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Error reading or processing JSON file: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# Determine the initial game state
$GameRunning = Check-GameState -FilePath $FullPath

# Create a FileSystemWatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $InputFolder
$watcher.Filter = $FileToMonitor
$watcher.NotifyFilter = [System.IO.NotifyFilters]'LastWrite, FileName, Size'
$watcher.EnableRaisingEvents = $true

# Register the FileSystemWatcher event
$onChanged = Register-ObjectEvent -InputObject $watcher -EventName Changed -Action {
    param($eventArgs)

    # Use a closure to reference $FullPath explicitly
    $FilePath = $eventArgs.FullPath

    try {
        Write-Host "File change detected: $FilePath" -ForegroundColor Yellow
        $jsonContent = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
        $FlagsValue = $jsonContent.Flags
        $Flags2Value = if ($jsonContent.PSObject.Properties.Name -contains 'Flags2') { $jsonContent.Flags2 } else { 0 }

        if (($FlagsValue -gt 0) -or ($Flags2Value -gt 0)) {
            if (-not $Script:GameRunning) {
                $Script:GameRunning = $true
                Write-Host "Game is now running! Flags detected." -ForegroundColor Green
            }
        } else {
            if ($Script:GameRunning) {
                $Script:GameRunning = $false
                Write-Host "Game is no longer running. Flags and Flags2 are zero." -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Error processing file change: $($_.Exception.Message)" -ForegroundColor Yellow
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
