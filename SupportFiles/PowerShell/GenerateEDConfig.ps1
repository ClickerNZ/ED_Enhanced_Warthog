# Determine the primary Status.json path using the current user profile.
$primaryStatusPath = Join-Path $env:USERPROFILE "Saved Games\Frontier Developments\Elite Dangerous\Status.json"

if (Test-Path $primaryStatusPath) {
    $statusFilePath = $primaryStatusPath
    Write-Output "Found Status.json at: $statusFilePath"
} else {
    Write-Warning "Status.json not found in the expected location: $primaryStatusPath"
    
    # If the user profile is already on the D: drive, report an error.
    if ($env:USERPROFILE -like "D:*") {
        Write-Error "Status.json file not found in the expected location on D: drive based on your user profile."
        exit 1
    }
    else {
        # Otherwise, attempt an alternative path on D:
        $alternativeProfile = "D:\Users\$env:USERNAME"
        $alternativeStatusPath = Join-Path $alternativeProfile "Saved Games\Frontier Developments\Elite Dangerous\Status.json"
        if (Test-Path $alternativeStatusPath) {
            $statusFilePath = $alternativeStatusPath
            Write-Output "Found Status.json at alternative D: drive path: $statusFilePath"
        } else {
            Write-Error "Status.json file not found on either the expected location or the alternative D: drive location."
            exit 1
        }
    }
}

# Define the output directory and configuration file path.
$supportDir = "C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles"
$outputFile = Join-Path $supportDir "ED_Enhanced_Warthog_Config.json"

# Ensure the support directory exists; create it if necessary.
if (-not (Test-Path -Path $supportDir)) {
    New-Item -ItemType Directory -Path $supportDir -Force | Out-Null
}

# Build the configuration object with the key TARGETConfig.
$configData = @{
    TARGETConfig = $statusFilePath
}

# Convert the configuration object to JSON.
$jsonContent = $configData | ConvertTo-Json -Depth 3

# Write the JSON content to the output file with UTF8 encoding.
Set-Content -Path $outputFile -Value $jsonContent -Encoding UTF8

Write-Output "Configuration file created at: $outputFile"
