# JSON Lookup using external lookup maps
# Global variable to store the imported maps
# Import-MapFile: Loads a JSON file into memory

function Import-MapFile {
    param (
        [string]$FilePath
    )

    if (-Not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }

    # Read and deserialize the JSON file
    $jsonContent = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
    $Global:LoadedMaps = $jsonContent
    Write-Output "Map file loaded successfully."
}

# Get-MappedValue: Retrieves a value from a map
function Get-MappedValue {
    param (
        [string]$MapName, # The name of the map (e.g ShipType_map)
        [string]$Key      # Accepts string keys
    )

    if (-Not $Global:LoadedMaps) {
        throw "No maps loaded. Use Import-MapFile to load the map file first."
    }

    # Check if the map name exists in the loaded maps
    if (-Not $Global:LoadedMaps.PSObject.Properties[$MapName]) {
        throw "Map '$MapName' not found in the loaded maps."
    }

    # Retrieve the map
    $map = $Global:LoadedMaps.$MapName

    # Check if the key exists in the map
    if ($map.PSObject.Properties.Name -contains $Key) {
        return $map.$Key
    } else {
        throw "Key '$Key' not found in map '$MapName'."
    }
}

# Export functions to make them available when the module is imported
Export-ModuleMember -Function Import-MapFile, Get-MappedValue
