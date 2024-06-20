:: Copyright (c) 2024 ShinTheBean

@echo off
title DISM
echo Prompting UAC to user..
if not "%1"=="am_admin" (powershell start -verb runas '%0' am_admin & exit /b)
:starts
cls
echo                    Created by shinthebean for PC Help Hub Discord
echo                  Any issues/queries contact shinthebean on Discord
echo                      https://gitlab.com/shinthebean/batchfiles
echo                                Credits to: jheden
echo.
:: Tests network connection for DISM /ONLINE
echo Testing network connection...
curl www.google.com >nul 2>&1
if %errorlevel% neq 0 (
echo No active Network Connection detected..
echo Unable to check for corruption.
echo Performing System File Check...
goto sfc
)

echo Network Connection detected! Continuing with script...
echo.
echo -------------------------------------------
echo             STARTING COMMANDS
echo -------------------------------------------
echo.
echo Select N for a quick scan
set /p "scanprompt=Would you like to do a thorough scan for corruption? (Y/N) "
echo.
if /i "%scanprompt%"=="Y" goto scanhealth
if /i "%scanprompt%"=="N" goto checkhealth
echo The option you chose isn't valid; Please select Y or N
echo Press any key to go back to the prompt.
pause > nul
goto :starts

:scanhealth
echo Performing a thorough scan for corruption..
echo Keep in mind this will take some time to complete (~5 minutes depending on system specs)
DISM /Online /Cleanup-Image /ScanHealth | findstr "No component store corruption detected"
if %errorlevel% EQU 0 (
	echo.
	goto sfc
) else (
	echo.
	goto corruption
)

:checkhealth
echo Performing a quick scan for corruption..
DISM /Online /Cleanup-Image /CheckHealth | findstr "No component store corruption detected"
if %errorlevel% EQU 0 (
	echo.
	goto sfc
) else (
	echo.
	goto corruption
)

:corruption
echo Corruption Detected, pushing fix..
echo Keep in mind this will take some time to complete (~15 minutes depending on system specs)
echo.
DISM /Online /Cleanup-Image /StartComponentCleanup >nul 2>&1
echo 1/2 Complete
DISM /Online /Cleanup-Image /RestoreHealth >nul 2>&1
echo 2/2 Complete
echo.
:sfc
echo Performing System File Check...
sfc /scannow | findstr "restart" >nul
if %errorlevel% EQU 0 (
	set restartneeded=true
)
echo System File Check has finished
echo.
echo -----------------------------------------
echo           COMMANDS FINISHED
echo -----------------------------------------
echo.
if "%restartneeded%"=="true" (
    powershell -window minimized -Command ""
    powershell -Command "Add-Type -AssemblyName PresentationFramework; $result = [System.Windows.MessageBox]::Show('Corruption has been fixed, but a restart is required for changes to apply; Press OK to Restart your PC', 'Restart Confirmation', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning); if ($result -eq [System.Windows.MessageBoxResult]::OK) { shutdown /r /t 0 }"
)

echo Press any key to exit...
pause > nul
exit /b
