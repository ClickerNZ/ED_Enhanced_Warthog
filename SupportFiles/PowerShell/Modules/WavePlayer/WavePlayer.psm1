<#
.SYNOPSIS
    Module to play .wav files with optional repetition and volume control.

.DESCRIPTION
    Play .wav files synchronously or asynchronously, with a specified number of repeats and volume control via Windows Media Player COM object.
#>

function Play-WavFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [switch]$Async,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Loops = 1,

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]$Volume = 100
    )

    if (-not (Test-Path -Path $Path)) {
        throw "File not found: $Path"
    }

    # Create Windows Media Player COM object
    $wmp = New-Object -ComObject WMPlayer.OCX
    $wmp.settings.volume = $Volume

    # Load media
    $media = $wmp.newMedia($Path)
    $wmp.currentPlaylist.clear()
    $wmp.currentPlaylist.appendItem($media)

    if ($Async.IsPresent) {
        # Play first iteration asynchronously and return
        $wmp.controls.play()
        return
    }

    # Synchronous playback for specified loops
    for ($i = 1; $i -le $Loops; $i++) {
        $wmp.controls.play()
        # Wait until playback stops (playState 3 = playing)
        while ($wmp.playState -eq 3) {
            Start-Sleep -Milliseconds 200
        }
        # Reset position for next iteration if needed
        if ($i -lt $Loops) {
            $wmp.controls.currentPosition = 0
        }
    }
}

Export-ModuleMember -Function Play-WavFile
