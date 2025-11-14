param (
    [Parameter(Mandatory = $true)]
    [string]$Configuration,

    [Parameter(Mandatory = $true)]
    [string]$Branch
)

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$xphoneBranchPath = $Branch
$gitPath = $scriptPath
$buildPath = Join-Path -Path $gitPath -ChildPath "x64\$Configuration\"
$xccPath = Join-Path -Path $xphoneBranchPath -ChildPath "_build\Debug\server\XCC"

class Binary {
    [string]$General
    [string]$Release
    [string]$Debug
}

$binariesToCopy = @(
    [PSCustomObject]@{ General = "FreeSwitch.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "FreeSwitchConsole.exe"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "fs_cli.exe"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "libapr.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "libbroadvoice.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "libpng16.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "libpq.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "libsndfile-1.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "libspandsp.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "libteletone.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "lua53.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "openssl.exe"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = $null; Release = "pcre.dll"; Debug = "pcred.dll" },
    [PSCustomObject]@{ General = "pocketsphinx.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "pthread.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "sphinxbase.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = $null; Release = "zlib.dll"; Debug = "zlibd.dll" },
    [PSCustomObject]@{ General = "\mod\FreeSWITCH.Managed.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\FreeSWITCH.ManagedCore.deps.json"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\FreeSWITCH.ManagedCore.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\FreeSWITCH.ManagedCore.runtimeconfig.json"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_callcenter.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_commands.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_conference.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_console.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_dialplan_xml.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_dptools.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_event_socket.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_expr.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_fifo.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_fsv.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_hash.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_local_stream.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_logfile.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_loopback.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_lua.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_managed.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_managedcore.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_native_file.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_opus.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_png.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_siren.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_sndfile.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_sofia.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_spandsp.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_tone_stream.dll"; Release = $null; Debug = $null },
    [PSCustomObject]@{ General = "\mod\mod_verto.dll"; Release = $null; Debug = $null }
)


function CopyDll ($dllName)
{
    $source = Join-Path -Path $buildPath -ChildPath $dllName 
    $destination = Join-Path -Path $xccPath -ChildPath $dllName
    $destinationDirectory = Split-Path -Path $destination -Parent
    
    New-Item -Path $destinationDirectory -ItemType Directory -Force
    Copy-Item -Path $source -Destination $destination -Force -ErrorAction Stop
    Set-ItemProperty -Path $destination -Name IsReadOnly -Value $false -ErrorAction Stop
}

function CopyPdb ($dllName)
{
    $directory = (Split-Path -Path $dllName -Parent)	
    if ([string]::IsNullOrEmpty($directory)) {
        $pdbName = [io.path]::GetFileNameWithoutExtension($dllName) + ".pdb"
    } else {
        $pdbName = Join-Path -Path $directory -ChildPath ([io.path]::GetFileNameWithoutExtension($dllName) + ".pdb")
    }
    $source = Join-Path -Path $buildPath -ChildPath $pdbName 
    $destination = Join-Path -Path $xccPath -ChildPath $pdbName
    $destinationDirectory = Split-Path -Path $destination -Parent
    
    if (Test-Path -path $source -PathType leaf)
    {
        New-Item -Path $destinationDirectory -ItemType Directory -Force
        Copy-Item -Path $source -Destination $destination -Force -ErrorAction Stop
        Set-ItemProperty -Path $destination -Name IsReadOnly -Value $false -ErrorAction Stop
    }
}


foreach ($binary in $binariesToCopy)
{
    $fileToCopy = $null

    if ($binary.General) {
        $fileToCopy = $binary.General
    }
    elseif ($Configuration -eq "Release" -and $binary.Release) {
        $fileToCopy = $binary.Release
    }
    elseif ($Configuration -eq "Debug" -and $binary.Debug) {
        $fileToCopy = $binary.Debug
    }

    if ($fileToCopy) {
      CopyDll $fileToCopy
      CopyPdb $fileToCopy
    }
    else {
        Write-Warning "Keine passende Datei gefunden für Konfiguration '$Configuration'"
    }
}
