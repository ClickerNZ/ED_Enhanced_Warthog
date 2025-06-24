# AutoPilot Powershell 5.1 function

function Start-AutopilotLoop {
    $statusFile = "C:\Users\YourName\Saved Games\Frontier Developments\Elite Dangerous\Status.json"
    $outputFile = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Output\MyJournalData.json"

    while ($Global:autopilotEnabled) {
        if (Test-Path $statusFile) {
            try {
                $status = Get-Content $statusFile -Raw | ConvertFrom-Json

                $currentLat = $status.Latitude
                $currentLon = $status.Longitude
                $planetRadius = $status.PlanetRadius

                if ($null -ne $currentLat -and $null -ne $currentLon -and $null -ne $planetRadius) {
                    $distance = Get-GroundDistance -Lat1 $currentLat -Lon1 $currentLon -Lat2 $Global:destLat -Lon2 $Global:destLon -Radius $planetRadius
                    $heading = Get-GroundHeading -Lat1 $currentLat -Lon1 $currentLon -Lat2 $Global:destLat -Lon2 $Global:destLon

                    $entry = @{
                        DestHeading  = [math]::Round($heading, 2)
                        DestDistance = [math]::Round($distance, 2)
                        Timestamp    = (Get-Date).ToString("o")
                    }
                    $entry | ConvertTo-Json -Depth 3 | Set-Content -Path $outputFile -Encoding UTF8

                    if ($distance -le 5000) {
                        Write-Host "Destination reached within 5km. Stopping autopilot."
                        $Global:autopilotEnabled = $false
                        break
                    }
                }
            } catch {
                Write-Host "Error reading status.json or calculating values: $_"
            }
        }

        Start-Sleep -Seconds 5
    }
}

function Get-GroundDistance {
    param (
        [double]$Lat1, [double]$Lon1,
        [double]$Lat2, [double]$Lon2,
        [double]$Radius
    )
    $dLat = ($Lat2 - $Lat1) * [math]::PI / 180
    $dLon = ($Lon2 - $Lon1) * [math]::PI / 180

    $a = [math]::Sin($dLat / 2) ** 2 + [math]::Cos($Lat1 * [math]::PI / 180) * [math]::Cos($Lat2 * [math]::PI / 180) * [math]::Sin($dLon / 2) ** 2
    $c = 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))

    return $Radius * $c
}

function Get-GroundHeading {
    param (
        [double]$Lat1, [double]$Lon1,
        [double]$Lat2, [double]$Lon2
    )
    $lat1Rad = $Lat1 * [math]::PI / 180
    $lat2Rad = $Lat2 * [math]::PI / 180
    $dLonRad = ($Lon2 - $Lon1) * [math]::PI / 180

    $y = [math]::Sin($dLonRad) * [math]::Cos($lat2Rad)
    $x = [math]::Cos($lat1Rad) * [math]::Sin($lat2Rad) - [math]::Sin($lat1Rad) * [math]::Cos($lat2Rad) * [math]::Cos($dLonRad)
    $brng = [math]::Atan2($y, $x)
    $brngDeg = ($brng * 180 / [math]::PI + 360) % 360

    return $brngDeg
}

# SendText handler
switch -Regex ($entry.Message) {
    '^!set\s+LAT\s+([-\d\.]+)' {
        $Global:destLat = [double]$matches[1]
        Write-Host "Set destination LAT: $($Global:destLat)"
    }
    '^!set\s+LON\s+([-\d\.]+)' {
        $Global:destLon = [double]$matches[1]
        Write-Host "Set destination LON: $($Global:destLon)"
    }
    '^!set\s+AP\s+ON' {
        if ($Global:destLat -ne $null -and $Global:destLon -ne $null) {
            $Global:autopilotEnabled = $true
            Start-Job { Start-AutopilotLoop }
            Write-Host "Autopilot started."
        } else {
            Write-Host "LAT/LON not set. Cannot start autopilot." -ForegroundColor Red
        }
    }
    '^!set\s+AP\s+OFF' {
        $Global:autopilotEnabled = $false
        Write-Host "Autopilot manually disabled."
    }
}
