$BuildPath="..\x64\Release\"
$XCCPath="D:\git\freeswitch\C4B\XCC\"

$filesToCopy = `
    "FreeSwitch.dll",
    "FreeSwitchConsole.exe",
    "fs_cli.exe",
    "libapr.dll",
    "libbroadvoice.dll",
    "libpng16.dll",
    "libpq.dll",
    "libsndfile-1.dll",
    "libspandsp.dll",
    "libteletone.dll",
    "lua53.dll",
    "openssl.exe",
    "pcre.dll",
    "pocketsphinx.dll",
    "pthread.dll",
    "sphinxbase.dll",
    "zlib.dll",
    "\mod\FreeSWITCH.Managed.dll",
    "\mod\FreeSWITCH.ManagedCore.deps.json",
    "\mod\FreeSWITCH.ManagedCore.dll",
    "\mod\FreeSWITCH.ManagedCore.runtimeconfig.json",
    "\mod\mod_callcenter.dll",
    "\mod\mod_commands.dll",
    "\mod\mod_conference.dll",
    "\mod\mod_console.dll",
    "\mod\mod_dialplan_xml.dll",
    "\mod\mod_dptools.dll",
    "\mod\mod_event_socket.dll",
    "\mod\mod_expr.dll",
    "\mod\mod_fifo.dll",
    "\mod\mod_fsv.dll",
    "\mod\mod_hash.dll",
    "\mod\mod_local_stream.dll",
    "\mod\mod_logfile.dll",
    "\mod\mod_loopback.dll",
    "\mod\mod_lua.dll",
    "\mod\mod_managed.dll",
    "\mod\mod_managedcore.dll",
    "\mod\mod_native_file.dll",
    "\mod\mod_opus.dll",
    "\mod\mod_png.dll",
    "\mod\mod_siren.dll",
    "\mod\mod_sndfile.dll",
    "\mod\mod_sofia.dll",
    "\mod\mod_spandsp.dll",
    "\mod\mod_tone_stream.dll",
    "\mod\mod_verto.dll"


function CopyDll ($dllName)
{
    $source = Join-Path -Path $BuildPath -ChildPath $dllName -Resolve -ErrorAction Stop
    $destination = Join-Path -Path $XCCPath -ChildPath $dllName
    $destinationDirectory = Split-Path -Path $destination -Parent
    
    New-Item -Path $destinationDirectory -ItemType Directory -Force
    Copy-Item -Path $source -Destination $destination -ErrorAction Stop
    Set-ItemProperty -Path $destination -Name IsReadOnly -Value $false -ErrorAction Stop
}


foreach ($file in $filesToCopy)
{
    CopyDll $file
}

# robocopy $BuildPath $XCCPath *.exe *.dll *.json /s /a-:R /xl /xx