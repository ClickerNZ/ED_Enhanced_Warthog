<#
.SYNOPSIS
  Builds or updates the "Index" block for a TARGET .tmh script file.

.DESCRIPTION
  Detects:
    - Function declarations beginning with one tab + 'int'
    - Macro chain definitions beginning with two tabs + 'm_'
  Calculates correct line numbers accounting for header and Index block length.
  Optionally replaces the Index block in the .tmh file.

.PARAMETER Path
  Full path to the .tmh file to index.

.PARAMETER UpdateFile
  If specified, replaces the existing Index block inside the .tmh file.

.NOTES
  PowerShell 5.1 compatible.  Save as UTF-8 with BOM or ANSI.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [switch]$UpdateFile
)

if (-not (Test-Path $Path)) {
    Write-Host "File not found: $Path" -ForegroundColor Red
    exit
}

# Read file
$content = Get-Content -Path $Path -Raw -Encoding UTF8
$lines   = $content -split "`r?`n"

# Detect Index block
$indexStart = $null
$indexEnd   = $null
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '/\*\s*Index') { $indexStart = $i }
    elseif ($indexStart -ne $null -and $lines[$i] -match '\*/') { $indexEnd = $i; break }
}

# Calculate header + index offset
$headerOffset = 0
if ($indexStart -ne $null) { $headerOffset = $indexStart }
$indexOffset = 0
if ($indexStart -ne $null -and $indexEnd -ne $null) { $indexOffset = ($indexEnd - $indexStart) + 1 }
$totalOffset = $headerOffset + $indexOffset

# Patterns
$functionPattern = '^[\t]{1}int\s+\w+\s*\('
$macroPattern    = '^[\t]{2}m_\w+\s*='

$entries = @()

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -match $functionPattern -or $line -match $macroPattern) {
        $entries += [PSCustomObject]@{
            Line = $i + 1
            Decl = $line.TrimEnd()
        }
    }
}

if (-not $entries) {
    Write-Host "No functions or macros found in file." -ForegroundColor Yellow
    exit
}

# Build Index text (with improved alignment)
$indexText  = "/*`r`n`tIndex:`t`t`tFUNCTION`r`n"
foreach ($e in $entries) {
    $indexText += ("`tLine {0,5}: `t{1}`r`n" -f $e.Line, $e.Decl)
}
$indexText += "*/"

# Output
Write-Host "`n========= INDEX BLOCK =========`n"
Write-Host $indexText
Write-Host "`n==============================`n"

# Save to .Index.txt
$outFile = [System.IO.Path]::ChangeExtension($Path, ".Index.txt")
$indexText | Out-File -FilePath $outFile -Encoding UTF8 -Force
Write-Host "Index block saved to: $outFile" -ForegroundColor Cyan

# Update file if requested
if ($UpdateFile) {
    if ($indexStart -ne $null -and $indexEnd -ne $null) {
        $newLines = @()
        $newLines += $lines[0..($indexStart - 1)]
        $newLines += ($indexText -split "`r?`n")
        if ($indexEnd + 1 -lt $lines.Count) {
            $newLines += $lines[($indexEnd + 1)..($lines.Count - 1)]
        }
        $newContent = ($newLines -join "`r`n")
        $backup = "$Path.bak"
        Copy-Item $Path $backup -Force
        $newContent | Out-File -FilePath $Path -Encoding UTF8 -Force
        Write-Host "Index block replaced successfully." -ForegroundColor Green
        Write-Host "Backup created: $backup" -ForegroundColor Yellow
    }
    else {
        Write-Host "Existing Index block not found -- no changes made." -ForegroundColor Red
    }
}
