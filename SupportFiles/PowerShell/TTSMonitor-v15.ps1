# TTSMonitor - v15
# Add code to detect when TTSExport.json is reset

# NOTE:	This version is superceded/replaced by V17.
#		This version reads and processes a single file which was being amended by TARGET script.
#		The issue was the TARGET script would error due to competing file locks etc.
#		Resolved by TARGET script writing one seeperate json file for each message.
#		v17 looks for new files inside the ...Output\TTSQueue subfolder the archives to another subfolder
#		after sending string etc to windows TTS engine

# Import the TTS module
Import-Module "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Modules\TTS\TTS.psm1"

# Path to the JSON file and state file
$jsonFile = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Output\TTSExport.json"
$stateFile = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Output\TTSState.txt"

# Reset state file on startup
$global:lastSeq = -1
Set-Content -Path $stateFile -Value -1
# $lastSeq = -1

# If state file exists, read last sequence and position
if (Test-Path $stateFile) {
    $state = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
    $global:lastSeq = $state.lastSeq    
}

# Variables to handle debounce and prevent multiple triggers
$processing = $false

# Function to process new JSON entries
function Process-TTSExport {
    if ($processing) { return } # Prevent re-entrancy
    $processing = $true

    try {
        # Debounce - Only process if file was modified
        $currentWriteTime = (Get-Item $jsonFile).LastWriteTime
        if ($currentWriteTime -eq $script:lastWriteTime) {
            $processing = $false
            return
        }

        $script:lastWriteTime = $currentWriteTime

        # Open the file stream and seek to last known position
        $reader = [System.IO.StreamReader]::new($jsonFile)

		# Detect gaps in TTSSeq values
		$seqValues = $jsonData | Where-Object { $_.TTSSeq -gt $global:lastSeq } | ForEach-Object { $_.TTSSeq } | Sort-Object
		for ($i = 0; $i -lt $seqValues.Count - 1; $i++) {
			if ($seqValues[$i + 1] - $seqValues[$i] -gt 1) {
				$missingRange = ($seqValues[$i] + 1)..($seqValues[$i + 1] - 1)
				Write-Host "Missing TTSSeq values: $($missingRange -join ', ')" -ForegroundColor Red 
			}
		}

		while (($line = $reader.ReadLine()) -ne $null) {
			if ($line.Trim() -ne "") {
				$entry = $line | ConvertFrom-Json

				# Only process new entries
				
				# Detect reset condition when TTSSeq restarts from 0 and file size decreases
				$fileSize = (Get-Item $jsonFile).Length
				if ($entry.TTSSeq -eq 0 -and $global:lastSeq -gt 0) {
					if ($global:lastFileSize -ne $null -and $fileSize -lt $global:lastFileSize) {
						Write-Host "Detected reset of TTSSeq due to file size change. Updating lastSeq to -1."
						$global:lastSeq = -1
					}
					$global:lastFileSize = $fileSize
					Set-Content -Path $stateFile -Value ($global:lastSeq | ConvertTo-Json -Compress)
				}

				if ($entry.TTSSeq -gt $global:lastSeq) {
					Write-Host "Processing TTSSeq $($entry.TTSSeq): $($entry.TTSString)"

					# Call the TTS class directly
					[TTS]::SpeakText($entry.TTSString, $entry.TTSVoice, $entry.TTSRate, $entry.TTSVolume)

					# Update last processed sequence
					$global:lastSeq = $entry.TTSSeq
					
					if ($entry.TTSString -eq "Game halted") {
						Write-Host "Game Halted detected, exiting..."

						# Send to TTS
						#[TTS]::SpeakText($entry.TTSString, $entry.TTSVoice, $entry.TTSRate, $entry.TTSVolume)

						# Clean up the watcher and exit
						$watcher.EnableRaisingEvents = $false
						Unregister-Event -SourceIdentifier FileChanged
						Write-Host "Watcher cleaned up. Exiting..."
						Stop-Process -Id $PID -Force  # Forcefully kill script
					}
				}
			}
        }

        # Save current position and sequence to state file
        $state = @{
            lastSeq = $global:lastSeq
        }
        $state | ConvertTo-Json | Set-Content -Path $stateFile

        $reader.Close()
    }
    catch {
        Write-Host "Error processing JSON file: $_"
    }
    finally {
        $processing = $false
    }
}

# Initialize FileSystemWatcher
$watcher = New-Object IO.FileSystemWatcher
$watcher.Path = [System.IO.Path]::GetDirectoryName($jsonFile)
$watcher.Filter = [System.IO.Path]::GetFileName($jsonFile)
$watcher.NotifyFilter = [IO.NotifyFilters]::LastWrite

# Event Handler with debounce logic
$action = {
    Start-Sleep -Milliseconds 250 # Small delay to avoid file lock issues
    Process-TTSExport
}

# Register Event Handlers *AFTER* setting initial state
Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action
Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action

# Set last write time AFTER attaching watcher to prevent initial trigger
$script:lastWriteTime = (Get-Item $jsonFile).LastWriteTime

Write-Host "Monitoring $jsonFile for changes" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop" -ForegroundColor Cyan								 

# Start monitoring
$watcher.EnableRaisingEvents = $true

# Keep script alive
while ($true) {
#    Start-Sleep -Seconds 1
    Start-Sleep -MilliSeconds 500
}
