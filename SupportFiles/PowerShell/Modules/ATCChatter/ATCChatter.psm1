# ATCChatter.psm1
# Elite Dangerous NPC "ATC-like" chatter using existing [TTS] module.
# PowerShell 5.1 compatible.

# USAGE:
# Add-ATCChatter "Text" $group (Station, Security or Traffic) to queue a TTS Message_Localised
# Invoke-ATCChatter to process next message in queue. Repeat calls until queue is empty.

# -------------------------
# Config (safe working voices; excludes Catherine/James + broken voices)
# -------------------------
$script:AllVoices = @(
  "Microsoft David Desktop",
#  "Microsoft Zira Desktop",
#  "Microsoft Heera",
#  "Microsoft Ravi",
#  "Microsoft Sean",
  "Microsoft Richard",
  "Microsoft Linda"
#  "Microsoft Mark"
)

# Voice groups (subset per type). Any missing names are ignored at pick-time.
$script:VoiceGroups = @{
  Station  = @("Microsoft David Desktop","Microsoft Richard")
  Security = @("Microsoft Richard","Microsoft David Desktop")
  Traffic  = @("Microsoft Linda","Microsoft David Desktop")

#  Station  = @("Microsoft David Desktop","Microsoft Mark","Microsoft Richard")
#  Security = @("Microsoft Sean","Microsoft Richard","Microsoft Ravi")
#  Traffic  = @("Microsoft Zira Desktop","Microsoft Linda","Microsoft Heera","Microsoft Mark")
}

# Background feel
$script:ATCVolume = 50   # 0..100
$script:ATCRate   = 0   # typically -10..10 (whatever your [TTS] supports)

# Optional "radio squelch"
$script:SquelchChance = 0.50
$script:SquelchText   = "kssht"
$script:SquelchVolDelta = 15
$script:SquelchRateDelta = 3

# Queue + state
$script:Queue = New-Object System.Collections.Generic.Queue[object]
$script:Lock  = New-Object object
$script:MaxQueue = 25

# Mute flags/state (driven by Status.json)
$script:IsDocked = $false
$script:IsOnFoot = $false
$script:IsInFSS  = $false
$script:Muted    = $false

function Get-ATCChatterMuted { return $script:Muted }

function Clear-ATCChatterQueue {
  [System.Threading.Monitor]::Enter($script:Lock)
  try { $script:Queue.Clear() } finally { [System.Threading.Monitor]::Exit($script:Lock) }
}

function Update-ATCChatterMuteState {
  $newMuted = ($script:IsDocked -or $script:IsOnFoot -or $script:IsInFSS)
  $changed = ($newMuted -ne $script:Muted)
  $script:Muted = $newMuted

  if ($changed -and $script:Muted) {
    Clear-ATCChatterQueue
  }
}

function Update-ATCChatterStateFromStatus([pscustomobject]$status) {
  if (-not $status) { return }

  $flags  = 0
  $flags2 = 0
  $gui    = 0

  if ($status.PSObject.Properties.Name -contains 'Flags' -and $null -ne $status.Flags) { $flags = [int64]$status.Flags }
  if ($status.PSObject.Properties.Name -contains 'Flags2' -and $null -ne $status.Flags2) { $flags2 = [int64]$status.Flags2 }
  if ($status.PSObject.Properties.Name -contains 'GuiFocus' -and $null -ne $status.GuiFocus) { $gui = [int]$status.GuiFocus }

  $script:IsDocked = (($flags  -band 1) -ne 0)   # Docked
  $script:IsOnFoot = (($flags2 -band 1) -ne 0)   # OnFoot
  $script:IsInFSS  = ($gui -eq 9)                # FSS

  Update-ATCChatterMuteState
}

function Get-ATCGroupForNpcReceiveText([pscustomobject]$entry) {
  $fromL = ""
  $from  = ""
  $msgL  = ""

  if ($entry -and ($entry.PSObject.Properties.Name -contains 'From_Localised') -and $null -ne $entry.From_Localised) { $fromL = [string]$entry.From_Localised }
  if ($entry -and ($entry.PSObject.Properties.Name -contains 'From') -and $null -ne $entry.From) { $from = [string]$entry.From }
  if ($entry -and ($entry.PSObject.Properties.Name -contains 'Message_Localised') -and $null -ne $entry.Message_Localised) { $msgL = [string]$entry.Message_Localised }

  if ($fromL -match 'Platform|Starport|Dock|Traffic Control|Control' -or
      $from  -match 'Platform' -or
      $msgL  -match 'Docking request granted|No fire zone|starport protocol|pad') {
    return "Station"
  }

  if ($fromL -match 'Security|Police|Authority|Service' -or
      $from  -match 'Police|Security') {
    return "Security"
  }

  return "Traffic"
}

function Pick-ATCVoice([string]$groupName) {
  $candidates = @()

  if ($script:VoiceGroups.ContainsKey($groupName)) {
    $candidates = @($script:VoiceGroups[$groupName] | Where-Object { $script:AllVoices -contains $_ })
  }
  if (-not $candidates -or $candidates.Count -eq 0) {
    $candidates = @($script:AllVoices)
  }
  return ($candidates | Get-Random)
}

function Add-ATCChatter([string]$text, [string]$group = "Traffic") {
  if ([string]::IsNullOrWhiteSpace($text)) { return }
  if ($script:Muted) { return }

  $t = $text.Trim()
  if ($t.Length -gt 220) { $t = $t.Substring(0, 220) }

  $item = [pscustomobject]@{ Text = $t; Group = $group }

  [System.Threading.Monitor]::Enter($script:Lock)
  try {
    while ($script:Queue.Count -ge $script:MaxQueue) { [void]$script:Queue.Dequeue() }
    $script:Queue.Enqueue($item)
  } finally {
    [System.Threading.Monitor]::Exit($script:Lock)
  }
}

function Invoke-ATCSquelch([string]$voice) {
  try {
    $v = [Math]::Max(0, [Math]::Min(100, ($script:ATCVolume - $script:SquelchVolDelta)))
    $r = ($script:ATCRate + $script:SquelchRateDelta)
    [TTS]::SpeakText($script:SquelchText, $voice, $r, $v)
  } catch { }
}

function Invoke-ATCChatter {
  # Speak at most ONE queued item per call (keeps your main loop responsive).
  if ($script:Muted) { return }

  $item = $null
  [System.Threading.Monitor]::Enter($script:Lock)
  try {
    if ($script:Queue.Count -gt 0) { $item = $script:Queue.Dequeue() }
  } finally {
    [System.Threading.Monitor]::Exit($script:Lock)
  }

  if (-not $item) { return }

  $text  = [string]$item.Text
  $group = ([string]$item.Group).Trim()
  if ([string]::IsNullOrWhiteSpace($text)) { return }

  $voice = Pick-ATCVoice $group

  # Optional squelch
  if ((Get-Random) -lt $script:SquelchChance) {
    Invoke-ATCSquelch $voice
  }

  $vol = $script:ATCVolume
  if ($group -eq "Station") {
    $vol += 15
  }

  # Clamp 0–100
  $vol = [Math]::Max(0, [Math]::Min(100, $vol))

	# --- Make delivery less robotic ---
	$spoken = $text.Trim()
	$spoken = $spoken -replace '\s+', ' '                  # normalize whitespace
	$spoken = $spoken -replace '(\.|!|\?)', '$1 '          # ensure space after sentence punctuation
	$spoken = $spoken -replace ',', ', '                   # slight pause cue

	# Light ATC-ish phrasing tweaks (optional; safe)
	$spoken = $spoken -replace '\bCommander\b', 'Commander,'

	# Small random variation each line
	$rate = $script:ATCRate + (Get-Random -Minimum -2 -Maximum 3)   # -2..+2
	$vol2 = $vol + (Get-Random -Minimum -2 -Maximum 3)              # -2..+2

	# Clamp
	$rate = [Math]::Max(-10, [Math]::Min(10, $rate))
	$vol2 = [Math]::Max(0, [Math]::Min(100, $vol2))

	try {
		[TTS]::SpeakText($spoken, $voice, $rate, $vol2)
	} catch {
		try { [TTS]::SpeakText($spoken, "Microsoft David Desktop", $rate, $vol2) } catch { }
	}
}

Export-ModuleMember -Function `
  Add-ATCChatter, Invoke-ATCChatter, `
  Get-ATCGroupForNpcReceiveText, Update-ATCChatterStateFromStatus, `
  Get-ATCChatterMuted, Clear-ATCChatterQueue
