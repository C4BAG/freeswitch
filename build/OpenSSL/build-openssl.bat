@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: OpenSSL Build Script fuer FreeSWITCH Windows
:: ============================================================
::
:: Baut OpenSSL aus dem Source-Code als statische Libraries
:: und kopiert das Ergebnis direkt nach libs\openssl-X.Y.Z\
:: im FreeSWITCH-Verzeichnisformat.
::
:: Die Version wird aus w32\openssl-version.props gelesen.
::
:: Voraussetzungen:
::   - Visual Studio 2017+ mit C++ Desktop-Workload
::   - Strawberry Perl im PATH
::   - NASM im PATH (optional, sonst wird no-asm verwendet)
::   - Git im PATH
::
:: Aufruf aus einer normalen CMD (nicht VS Developer Prompt):
::   build\OpenSSL\build-openssl.bat
::
:: ============================================================

:: Pfade ermitteln
set SCRIPTDIR=%~dp0
set REPOROOT=%SCRIPTDIR%..\..

:: Repo-Root normalisieren (trailing backslash entfernen)
pushd "%REPOROOT%"
set REPOROOT=%CD%
popd

:: ============================================================
:: Version aus w32\openssl-version.props lesen
:: ============================================================
set PROPSFILE=%REPOROOT%\w32\openssl-version.props
if not exist "%PROPSFILE%" (
    echo [FEHLER] %PROPSFILE% nicht gefunden!
    exit /b 1
)

set VERSION=
for /f "tokens=3 delims=<>" %%A in ('findstr "<OpenSSLVersion>" "%PROPSFILE%"') do set VERSION=%%A

if "%VERSION%"=="" (
    echo [FEHLER] Konnte OpenSSLVersion nicht aus %PROPSFILE% lesen!
    exit /b 1
)

set TAG=openssl-%VERSION%

:: Build-Verzeichnisse (alles unter build\OpenSSL\_build\)
set BUILDDIR=%SCRIPTDIR%_build
set SRCDIR=%BUILDDIR%\openssl-%VERSION%-src
set OUTDIR=%BUILDDIR%\output

:: Zielverzeichnis in libs
set LIBSDIR=%REPOROOT%\libs\openssl-%VERSION%

:: ============================================================
:: Visual Studio finden
:: ============================================================
set VCVARS=
for %%E in (Enterprise Professional Community) do (
    for %%Y in (2022 2019 2017) do (
        if not defined VCVARS (
            if %%Y GEQ 2022 (
                set "_CHECK=C:\Program Files\Microsoft Visual Studio\%%Y\%%E\VC\Auxiliary\Build\vcvarsall.bat"
            ) else (
                set "_CHECK=C:\Program Files (x86)\Microsoft Visual Studio\%%Y\%%E\VC\Auxiliary\Build\vcvarsall.bat"
            )
            if exist "!_CHECK!" set "VCVARS=!_CHECK!"
        )
    )
)
if not defined VCVARS (
    echo [FEHLER] Visual Studio nicht gefunden!
    exit /b 1
)
echo [INFO] Visual Studio: %VCVARS%

:: ============================================================
:: Tools pruefen
:: ============================================================
where perl >nul 2>&1 || (echo [FEHLER] Perl nicht gefunden! & exit /b 1)
echo [INFO] Perl OK

set ASM_OPT=
where nasm >nul 2>&1
if errorlevel 1 (
    echo [WARNUNG] NASM nicht gefunden - baue mit no-asm
    set ASM_OPT=no-asm
) else (
    echo [INFO] NASM OK
)

:: ============================================================
:: Verzeichnisse vorbereiten
:: ============================================================
echo.
echo [INFO] OpenSSL Version:    %VERSION%
echo [INFO] Build-Verzeichnis:  %BUILDDIR%
echo [INFO] Zielverzeichnis:    %LIBSDIR%
echo.

if not exist "%BUILDDIR%" mkdir "%BUILDDIR%"
if exist "%OUTDIR%" rmdir /S /Q "%OUTDIR%"
mkdir "%OUTDIR%"

:: Zielverzeichnis leeren falls vorhanden
if exist "%LIBSDIR%" (
    echo [INFO] Loesche altes Zielverzeichnis %LIBSDIR% ...
    rmdir /S /Q "%LIBSDIR%"
)

:: ============================================================
:: Quellcode holen
:: ============================================================
if exist "%SRCDIR%" (
    echo [INFO] Loesche alten Quellcode...
    rmdir /S /Q "%SRCDIR%"
)

echo [INFO] Klone OpenSSL %VERSION% ...
git clone --depth 1 --branch %TAG% https://github.com/openssl/openssl.git "%SRCDIR%"
if errorlevel 1 (
    echo [FEHLER] Git clone fehlgeschlagen!
    exit /b 1
)

:: ============================================================
:: Builds ausfuehren
:: ============================================================
call :do_build x64 amd64 VC-WIN64A Release
if errorlevel 1 goto :fatal

call :do_build x64 amd64 VC-WIN64A Debug
if errorlevel 1 goto :fatal

:: Fuer Win32 einkommentieren:
:: call :do_build Win32 x86 VC-WIN32 Release
:: if errorlevel 1 goto :fatal
:: call :do_build Win32 x86 VC-WIN32 Debug
:: if errorlevel 1 goto :fatal

:: ============================================================
:: Ergebnis nach libs\openssl-X.Y.Z\ kopieren
:: ============================================================
echo.
echo ============================================================
echo  Kopiere Ergebnis nach %LIBSDIR%
echo ============================================================

call :copy_binaries x64 Release
if errorlevel 1 goto :fatal

call :copy_binaries x64 Debug
if errorlevel 1 goto :fatal

:: Fuer Win32 einkommentieren:
:: call :copy_binaries Win32 Release
:: call :copy_binaries Win32 Debug

call :copy_headers x64
if errorlevel 1 goto :fatal

:: Fuer Win32 einkommentieren (erzeugt include_x86):
:: call :copy_platform_config Win32 include_x86

:: ============================================================
:: Zusammenfassung
:: ============================================================
echo.
echo ============================================================
echo  BUILD ABGESCHLOSSEN
echo ============================================================
echo.
echo  OpenSSL %VERSION% installiert nach:
echo    %LIBSDIR%
echo.
echo  Verzeichnisstruktur:
dir /S /B "%LIBSDIR%\binaries" 2>nul
echo.
echo  Naechste Schritte:
echo    - FreeSWITCH-Solution in Visual Studio oeffnen und bauen
echo    - Ggf. openssl.props anpassen (zusaetzliche Libs, API-Aenderungen)
echo ============================================================
goto :done

:: ############################################################
:: SUBROUTINEN
:: ############################################################

:: ============================================================
:: do_build - OpenSSL kompilieren
:: %1=Platform  %2=vcarch  %3=sslTarget  %4=Config
:: ============================================================
:do_build
setlocal
set PLAT=%~1
set VCARCH=%~2
set SSLTARGET=%~3
set CONFIG=%~4
set INSTALLDIR=%OUTDIR%\%PLAT%-%CONFIG%

:: Debug-Prefix
set DBGPREFIX=
if /i "%CONFIG%"=="Debug" set DBGPREFIX=debug-

echo.
echo ============================================================
echo  Baue OpenSSL %VERSION% - %PLAT% %CONFIG%
echo  Target: %DBGPREFIX%%SSLTARGET% no-shared %ASM_OPT%
echo ============================================================

cd /d "%SRCDIR%"

:: Vorherigen Build aufraeumen
if exist Makefile (
    cmd /c "call "%VCVARS%" %VCARCH% >nul 2>&1 && nmake clean >nul 2>&1"
)

:: Konfigurieren + Bauen + Installieren
cmd /c "call "%VCVARS%" %VCARCH% && perl Configure %DBGPREFIX%%SSLTARGET% no-shared %ASM_OPT% --prefix="%INSTALLDIR%" --openssldir="%INSTALLDIR%\ssl" && nmake && nmake install_sw"
if errorlevel 1 (
    echo [FEHLER] Build fehlgeschlagen: %PLAT% %CONFIG%
    endlocal & exit /b 1
)

echo [OK] Build erfolgreich: %PLAT% %CONFIG%
echo     Installiert nach: %INSTALLDIR%

:: Aufraeumen
cmd /c "call "%VCVARS%" %VCARCH% >nul 2>&1 && cd /d "%SRCDIR%" && nmake clean >nul 2>&1"

endlocal & exit /b 0

:: ============================================================
:: copy_binaries - Binaries in libs-Struktur kopieren
:: %1=Platform  %2=Config
:: ============================================================
:copy_binaries
setlocal
set PLAT=%~1
set CONFIG=%~2
set BINOUT=%OUTDIR%\%PLAT%-%CONFIG%
set DESTDIR=%LIBSDIR%\binaries\%PLAT%\%CONFIG%

echo [INFO] Kopiere Binaries: %PLAT% %CONFIG%...

mkdir "%DESTDIR%" 2>nul

:: Statische Libs
copy "%BINOUT%\lib\libssl.lib"    "%DESTDIR%\" >nul 2>&1
copy "%BINOUT%\lib\libcrypto.lib" "%DESTDIR%\" >nul 2>&1

:: openssl.exe
copy "%BINOUT%\bin\openssl.exe" "%DESTDIR%\" >nul 2>&1

:: PDB-Dateien
copy "%BINOUT%\lib\ossl_static.pdb" "%DESTDIR%\" >nul 2>&1
copy "%BINOUT%\bin\openssl.pdb"     "%DESTDIR%\" >nul 2>&1

:: Pruefen ob wichtigste Dateien da sind
if not exist "%DESTDIR%\libssl.lib" (
    echo [FEHLER] libssl.lib nicht gefunden!
    echo [INFO] Inhalt von %BINOUT%\lib:
    dir /B "%BINOUT%\lib" 2>&1
    endlocal & exit /b 1
)
if not exist "%DESTDIR%\libcrypto.lib" (
    echo [FEHLER] libcrypto.lib nicht gefunden!
    endlocal & exit /b 1
)

echo [OK] libssl.lib    - OK
echo [OK] libcrypto.lib - OK

endlocal & exit /b 0

:: ============================================================
:: copy_headers - Headers und plattformspezifische Config kopieren
:: %1=Platform (fuer die Haupt-Headers, z.B. x64)
:: ============================================================
:copy_headers
setlocal
set PLAT=%~1
set SRCHEADERS=%OUTDIR%\%PLAT%-Release\include\openssl

echo [INFO] Kopiere Headers...

:: Alle Headers nach include\openssl\
mkdir "%LIBSDIR%\include\openssl" 2>nul
xcopy /E /I /Q /Y "%SRCHEADERS%" "%LIBSDIR%\include\openssl"

:: Plattformspezifische configuration.h nach include_x64\openssl\
mkdir "%LIBSDIR%\include_x64\openssl" 2>nul
copy /Y "%SRCHEADERS%\configuration.h" "%LIBSDIR%\include_x64\openssl\configuration.h" >nul

:: include_x86: Falls Win32 gebaut wurde, wird copy_platform_config separat aufgerufen.
:: Fallback: Leeres include_x86 anlegen damit der Build nicht bricht.
if not exist "%LIBSDIR%\include_x86\openssl" (
    mkdir "%LIBSDIR%\include_x86\openssl" 2>nul
    :: Platzhalter-configuration.h - muss fuer echte Win32-Builds ersetzt werden
    if exist "%OUTDIR%\Win32-Release\include\openssl\configuration.h" (
        copy /Y "%OUTDIR%\Win32-Release\include\openssl\configuration.h" "%LIBSDIR%\include_x86\openssl\configuration.h" >nul
    ) else (
        echo [WARNUNG] Kein Win32-Build - include_x86\openssl\configuration.h fehlt.
        echo [WARNUNG] Fuer Win32-Builds muss OpenSSL auch fuer Win32 gebaut werden.
    )
)

echo [OK] Headers kopiert

endlocal & exit /b 0

:: ============================================================
:fatal
echo.
echo [FEHLER] Build abgebrochen!
exit /b 1

:done
endlocal
exit /b 0
