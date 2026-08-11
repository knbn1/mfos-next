:: Source code of MicroflashOS Next
:: A "fantasy operating system" made by KNBnoob1!
:: Project source: https://github.com/knbn1/mfos-next
:: Contributors: nightlydevice, nglammm, justapawsibility

:: Define MicroflashOS Batch file location

set "mfosLocation=%~dp0"

:: Strip the trailing '.' which can cause issues

set "mfosLocation=%mfosLocation:~0,-1%"

:: Define version string

set "mfosVer=2026.08.11"

:: Define default directories

set "sysDir=mfos"
set "modsDir=usermods"
set "userData=userdata"
set "userSysData=mfosdata"
set "disk0Label=MicroflashOS"

:: Define default user - %username% environment variable

set "user=%username%"

:: Boot process stage 0 - Bootloader

:bootstagezero

cd /d "%mfosLocation%"
title MicroflashOS Bootloader

:: System disk stuffs

set "disk0=%mfosLocation%\%disk0Label%"
set "disk0p1=%disk0%\%sysDir%"
set "disk0p2=%disk0%\%userData%"

:: Special directories

set "devices=%disk0p1%\devices"
set "exeCache=%devices%\memsect2\execache"

set "userDir=%disk0p2%\%user%"
set "userSysDatadir=%userDir%\%userSysData%"
set "toggles=%userSysDatadir%\toggles"
set "userMods=%userSysDatadir%\%modsDir%"
set "pkgDir=%userSysDatadir%\packages"
set "pkgMeta=%pkgDir%\installed"
set "pkgHelp=%disk0p1%\docs"

set "excludeWriteCheck=.git"

:: Modules loaded as part of the boot process

set "sysModDeps=cmd core fsutils compact proctector neopkg devtools userspace"

:: Specify which user modules to load with usermods.txt

set "userModsAllowed="
if exist usermods.txt (set /p userModsAllowed=<"usermods.txt")

:: Whitelisted and blacklisted commands

set "cmdlist=about help clock print clear reboot writerecheck shutdown mkdir mkfile rename delete list cd home homewipe neopkg mountsys modules toggles getvars users"
set "disallowed=mkfile"

:: Startup parameters

if exist "%toggles%\echoon" (@echo on) else (@echo off)
if not exist "%toggles%\noclear" (cls)
if not exist "%toggles%\nolog" (set "logfile=%mfosLocation%\mfos-log.txt") else (set "logfile=NUL")
if not exist "%toggles%\incognito" (set "history=%userDir%/mfos-history.txt") else (set "history=NUL")

:: Flag directory writability

call :checkWritable "%mfosLocation%" "%excludeWriteCheck%" 0 
if ERRORLEVEL 10 (call :writeCheckFail boot)
set "dirWritable=yessir" & set "homeWritable=yessir"

:: Start logging

echo. >>"%logfile%"
echo %time% %date% >>"%logfile%"
echo ========================================= >>"%logfile%"
echo [bootloader] INFO: to log or not to log, that is the question >>"%logfile%"
echo [bootloader] INFO: logging system initialized
echo [bootloader] INFO: log file: %logfile%

if exist "%toggles%\slowboot" (call :slowboot)

:: Transfer control to kernel (lore stuff)

echo [bootloader] INFO: loading bundled kernel into memory... >>"%logfile%"
echo [kernel] INFO: hello world, my version is %mfosVer% >>"%logfile%"
echo.

:: System disk check

title Finding system disk...
if not exist "%disk0Label%" (
    echo Unable to mount system disk!
    echo [kernel] ERROR: system disk mount failure >>"%logfile%"
    goto bootfail
)
echo System disk "%disk0Label%" mounted as /
echo [kernel] INFO: system disk is "%disk0Label%" mounted as / >>"%logfile%"

:: Version check

set /p oldver=<"%disk0p1%/version.txt"
echo.
echo Checking version strings...
echo.
echo Bundled kernel: %mfosVer%
echo Detected kernel: %oldver%
echo.
if not "%oldver%"=="%mfosVer%" (
    echo Version mismatch!
    echo [kernel] ERROR: expected "%mfosVer%" but got "%oldver%" >>"%logfile%"
    goto bootfail
)
echo MicroflashOS is on the latest version!
echo [kernel] INFO: version string valid >>"%logfile%"

:: System partition check

if not exist "%disk0p1%" (
    echo.
    echo Could not find the system partition!
    echo Please redownload a system disk from GitHub Releases.
    echo.
    echo https://github.com/knbn1/mfos-next/releases/latest
    echo [kernel] ERROR: no system partition >>"%logfile%"
    goto bootfail
)

:: Boot process stage 1 - Initialize devices

:bootstageone

echo [kernel] INFO: begin boot process stage 1 >>"%logfile%"

if exist "%toggles%\slowboot" (call :slowboot)

echo.
title Initializing devices...
echo Initializing devices...
echo.

cd /d "%disk0p1%"
if not exist "%devices%" (md devices)
if not exist "%pkgHelp%" (md help)

echo [kdevinit] INFO: found devices directory in disk0p1 >>"%logfile%"
echo [kdevinit] INFO: found help sections directory in disk0p1 >>"%logfile%"
echo System partition > "%devices%\disk0p1"
call :devinitok disk0p1

echo ^:^: Memory Sector 1 >"%devices%\memsect1.bat"
echo [kdevinit] INFO: generated memsect1 >>"%logfile%"
call :devinitok memsect1

if not exist "%devices%\memsect2" (md "%devices%\memsect2")
echo [kdevinit] INFO: generated memsect2 >>"%logfile%"
if not exist "%exeCache%" (mkdir "%devices%\memsect2\execache")
echo [kdevinit] INFO: generated memsect2 neopkg execache >>"%logfile%"
call :devinitok memsect2

echo Memory sector 3 - Secret Block >"%devices%\memsect3"
echo [kdevinit] INFO: generated memsect3 >>"%logfile%"
call :devinitok memsect3

if exist "%toggles%\slowboot" (call :slowboot)

:: Boot process stage 2 - Load core modules

:bootstagetwo

echo [kernel] INFO: begin boot process stage 2 >>"%logfile%"

echo.
title Loading core modules...
echo Loading core modules...
echo.

for %%C in (%sysModDeps%) do (
    if not exist "%disk0p1%\%%C.mcm" (
        call :loadmodfail "/%sysDir%/%%C.mcm"
    )
    echo. >>"%devices%\memsect1.bat"
    type "%disk0p1%\%%C.mcm" >>"%devices%\memsect1.bat"
    call :loadmodok "/%sysDir%/%%C.mcm"
)

if exist "%toggles%\slowboot" (call :slowboot)

:: Boot process stage 3 - Userdata partition

:bootstagethree

echo [kernel] INFO: begin boot process stage 3 >>"%logfile%"

title Checking userdata partition...

echo.
if not exist "%disk0p2%" (
    echo Userdata partition not found!
    echo [kdevinit] WARN: failed to initialize userdata partition >>"%logfile%"
    echo.
    echo Creating userdata partition...
    echo [kusrinit] INFO: creating userdata partition >>"%logfile%"
    md "%disk0p2%"
    echo.
)

:: the bare minimum to get stuff to work
:: if mfos breaks you will need to download the latest system disks from github
rem Don't worry, It can't break with my new writability check
:: fuck you nightlydevice

if not exist "%userDir%" (
    echo Userdata for user %user% not found!
    echo [kusrinit] WARN: no userdata found for user %user% >>"%logfile%"
    echo.
    echo Creating userdata for %user%...
    echo [kusrinit] INFO: creating userdata for user %user% >>"%logfile%"
    md "%userDir%"
    echo.
)

if not exist "%userSysDatadir%" (
    echo Setting up userdata for %user%...
    echo [kusrinit] INFO: setting up userdata for %user% >>"%logfile%"
    md "%userSysData%"
    echo.
)

if not exist "%toggles%" (
    echo Creating toggle directory...
    echo [kusrinit] INFO: creating toggle directory for %user% >>"%logfile%"
    md "%toggles%"
    echo.
)

if not exist "%pkgDir%" (
    echo Creating package directory...
    echo [kusrinit] INFO: creating package directory for %user% >>"%logfile%"
    md "%pkgDir%\help"
    md "%pkgDir%\installed"
    echo.
)

if not exist "%userMods%\" (
    echo Creating module directory...
    echo [kusrinit] INFO: creating module directory for %user% >>"%logfile%"
    cd /d "%userSysDatadir%"
    md %modsDir%
    echo.
)

:: Load user modules

if "%userModsAllowed%"=="" (
    echo No user modules to load, skipping...
    echo [kusrinit] INFO: no user modules were whitelisted, skipping... >>"%logfile%"
) else (
    title Loading user modules...
    echo Loading user modules...
    echo.
    for %%U in (%userModsAllowed%) do (
        if exist "%userMods%\%%U.mfm" (
            echo. >>"%devices%\memsect1.bat"
            type "%userMods%\%%U.mfm" >>"%devices%\memsect1.bat"
            call :loadmodok %%U.mfm
        )
    )
)

:: Once finished make a device for disk0p2 aka userdata
:: Doesn't do jackshit but it's for the lore

echo Userdata partition > "%devices%\disk0p2"

if exist "%toggles%\slowboot" (call :slowboot)

:: Boot process complete!

:bootcomplete

title Boot process complete!
echo.
echo MicroflashOS system files loaded!
echo [kernel] INFO: boot process completed >>"%logfile%"
cd /d "%userDir%"

if exist "%toggles%\slowboot" (call :slowboot)

if not exist "%toggles%\noclear" (cls)
echo.
echo Welcome to MicroflashOS!
echo [cmd] INFO: initialized prompt >>"%logfile%"
echo.
echo Logged in as %user%
echo [cmd] INFO: current user: %user% >>"%logfile%"
echo.
echo Type HELP for a list of commands.
echo Commands are not case-sensitive.

:: User prompt

:prompt

:: check if a reboot has been enforced

if "%enforcereboot%" == "true" (
    set "enforcereboot=false"
    echo The system will now reboot.
    call :halt
    title Rebooting...
    echo [kernel] INFO: intercepted reboot request >>"%logfile%"
    goto bootstagezero
)

:: Titlebar stuff

set "titlebar=MicroflashOS %mfosVer%"
title %titlebar%
if exist "%userMods%\devtools.mfm" (title %titlebar% [DevTools])

if exist "%toggles%\showdir" (
    echo [cmd] DEBUG: showing current directory >>"%logfile%"
    echo Current directory: %cd%
    echo.
)

:: Immediately jump to memsect1 to parse commands
:: Potential scripting support soon??

call "%devices%\memsect1.bat" :parser
goto prompt

:: Consolidations

::%1=dir, %2=excludeDirs, %3=depthCount || %4=tmpFilename
::ERRORLEVELs: 10=read-only, 3=depth exceeded, 2=skipped
:checkWritable
if "%~1"=="" (exit /b 0)

set /a "recurseLimit=100"
if %3 GEQ %recurseLimit% (exit /b 3)
set /a "depth=%3 +1"

set "_dir=%~nx1" & set "_excludeDirs=%~2"
call set "_skipThis=%%excludeDirs:%dir%=%%"
if not "%_skipThis%"=="%_excludeDirs%" (exit /b 2)

rem Current level check
type nul > "%~f1\%4.tmp"
if not exist "%~f1\%4.tmp" (exit /b 10)
del "%~f1\%4.tmp"

rem Check subdirectories
for /d %%Z in ("%~f1\*") do (
    call :checkWritable "%%~fZ" "%~2" %depth%
    if ERRORLEVEL 10 (exit /b 10)
)

set "_dir=" & set "_excludeDirs="
set "_skip=" & set "depth="
exit /b

:devinitok
echo Initialized %1
echo [kdevinit] INFO: %1 initialized >>"%logfile%"
goto :eof

:loadmodok
echo Loaded %~1
echo [kmodsinit] INFO: loaded %~1 >>"%logfile%"
goto :eof

:devinitfail
echo Could not initialize device "%1"
echo [kdevinit] ERROR: failed to initialize "%1" >>"%logfile%"
goto bootfail

:loadmodfail
echo.
echo FAIL %~1
echo [kmodsinit] ERROR: failed to load %~1 >>"%logfile%"
goto bootfail

:writeCheckFail
echo.
echo Cannot boot with read-only home directory.
if "%1"=="boot" (goto bootfail)
goto :eof

:bootfail
echo.
title Startup Failure!
echo MicroflashOS startup failed.
goto pauseexit

:slowboot
echo.
echo Slowboot toggle tripped!
call :halt
echo [bootloader] DEBUG: slowboot toggle tripped >>"%logfile%"
goto :eof

:pauseexit
call :halt
cmd /k exit

:halt
echo.
pause
goto :eof


