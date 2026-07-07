#requires -Version 5.1
<#
.SYNOPSIS
  Live view of a channel's ICE state via 'uuid_dump_ice', polled every 300 ms.
  Re-renders only when the ICE-state fingerprint changes (hash gating), so a
  stable call stays quiet and only real connectivity changes redraw the screen.

.DESCRIPTION
  If -Uuid is given, that channel is polled directly.
  Otherwise the script discovers a channel: it lists 'show channels as json',
  filters by -Direction, and probes each candidate with 'uuid_dump_ice ... hash'
  (skipping channels that answer '-ERR ICE not used'). The first WebRTC/ICE
  channel found is polled. Start the script BEFORE placing the call so it can
  latch onto the new leg (use -Direction outbound to target the callee leg B in
  an A -> B scenario).

.PARAMETER Uuid        Poll this channel directly (skips discovery).
.PARAMETER Direction   Discovery filter: inbound | outbound | any  (default outbound).
.PARAMETER IntervalMs  Poll interval in milliseconds (default 300).
.PARAMETER HashLevel   Fingerprint used for gating: info | debug (default info).
.PARAMETER Password    fs_cli event-socket password (default XPhoneTheBrave).
.PARAMETER FsCli       Path to fs_cli.exe (default 'fs_cli', i.e. on PATH).

.EXAMPLE
  .\ice_poll.ps1 -Uuid 91adc759-2b60-4545-a2e8-dd04c4875bbb
.EXAMPLE
  .\ice_poll.ps1 -Direction outbound -HashLevel debug
.EXAMPLE
  .\ice_poll.ps1 -FsCli 'D:\...\_Build\Release\server\XCC\fs_cli.exe'
#>
[CmdletBinding()]
param(
    [string]$Uuid,
    [ValidateSet('inbound','outbound','any')]
    [string]$Direction = 'outbound',
    [int]$IntervalMs = 300,
    [ValidateSet('info','debug')]
    [string]$HashLevel = 'info',
    [string]$Password = 'XPhoneTheBrave',
    [string]$FsCli,
    [switch]$Clear,
    [string]$LogFile,
    [switch]$Follow
)

# Footgun guard: if a direction was passed positionally (it binds to -Uuid),
# treat it as -Direction and fall into discovery mode instead of polling a
# channel literally named 'outbound'.
if ($Uuid -and @('inbound','outbound','any') -contains $Uuid.ToLower()) {
    $Direction = $Uuid.ToLower()
    $Uuid = $null
    Write-Host ("(interpreting positional '{0}' as -Direction)" -f $Direction) -ForegroundColor DarkGray
}

# Resolve fs_cli.exe: explicit -FsCli wins; otherwise prefer fs_cli.exe next to
# this script (the XCC dir), then fall back to 'fs_cli' on PATH.
if (-not $FsCli) {
    $local = Join-Path $PSScriptRoot 'fs_cli.exe'
    if (Test-Path $local) { $FsCli = $local } else { $FsCli = 'fs_cli' }
}
Write-Host ("Using fs_cli: {0}" -f $FsCli) -ForegroundColor DarkGray

# One-shot fs_cli call; returns stdout joined into a single string.
function Invoke-Fs {
    param([string]$Command)
    (& $FsCli -p $Password -x $Command 2>$null) -join "`n"
}

# Returns the uuid of a channel matching -Direction that actually uses ICE, or $null.
function Find-IceChannel {
    $json = Invoke-Fs 'show channels as json'
    if (-not $json) { return $null }
    try { $rows = ($json | ConvertFrom-Json).rows } catch { return $null }
    if (-not $rows) { return $null }

    $cands = $rows
    if ($Direction -ne 'any') { $cands = $rows | Where-Object { $_.direction -eq $Direction } }

    foreach ($r in ($cands | Sort-Object created_epoch)) {
        $probe = Invoke-Fs ("uuid_dump_ice {0} hash info" -f $r.uuid)
        if ($probe -notmatch '^-ERR') { return $r.uuid }   # first leg that has ICE
    }
    return $null
}

# Print to console and, if -LogFile is set, append the same text to the file.
function Write-Out {
    param([string]$Text, [System.ConsoleColor]$Color = [System.ConsoleColor]::Gray)
    Write-Host $Text -ForegroundColor $Color
    if ($LogFile) { Add-Content -LiteralPath $LogFile -Value $Text }
}

# Poll one channel until it ends. Appends a timestamped block on every change
# (timeline), or redraws the screen each change when -Clear is given (dashboard).
function Poll-Channel {
    param([string]$ChannelUuid)
    $last = ''
    Write-Out ("----- polling {0} every {1} ms (Ctrl+C to stop) -----" -f $ChannelUuid, $IntervalMs) ([System.ConsoleColor]::Cyan)
    while ($true) {
        $h = (Invoke-Fs ("uuid_dump_ice {0} hash {1}" -f $ChannelUuid, $HashLevel)).Trim()

        if ($h -match '^-ERR') {
            Write-Out ("===== [{0}] channel {1} ended: {2} =====" -f (Get-Date -Format 'HH:mm:ss.fff'), $ChannelUuid, $h) ([System.ConsoleColor]::Yellow)
            return
        }

        if ($h -ne $last) {
            $last = $h
            $full = Invoke-Fs ("uuid_dump_ice {0}" -f $ChannelUuid)
            if ($Clear) { Clear-Host }
            Write-Out ("===== [{0}] change  {1}={2} =====" -f (Get-Date -Format 'HH:mm:ss.fff'), $HashLevel, $h) ([System.ConsoleColor]::DarkGray)
            Write-Out $full
        }

        Start-Sleep -Milliseconds $IntervalMs
    }
}

# --- main loop: discover -> poll -> optionally follow the next call ---
if ($LogFile) { Write-Host ("Logging timeline to {0}" -f $LogFile) -ForegroundColor DarkGray }

while ($true) {
    if ($Uuid) {
        $target = $Uuid
        $Uuid = $null                 # subsequent -Follow rounds use discovery
    } else {
        Write-Host ("Discovering first '{0}' channel using ICE (Ctrl+C to abort)..." -f $Direction) -ForegroundColor Cyan
        $target = $null
        while (-not $target) {
            $target = Find-IceChannel
            if (-not $target) { Start-Sleep -Milliseconds $IntervalMs }
        }
        Write-Host ("Found channel: {0}" -f $target) -ForegroundColor Green
    }

    Poll-Channel $target

    if (-not $Follow) { break }
    Write-Host "Waiting for next call..." -ForegroundColor Cyan
}
