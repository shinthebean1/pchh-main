Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    Write-Host "Powershell needs to be run as an Administrator for this to work."
    Write-Host "Press any key to exit the script!"
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") > $null
    exit
}

Clear-Host

$null = New-Module {
    function Invoke-WithoutProgress {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)] [scriptblock] $ScriptBlock
        )

        $prevProgressPreference = $global:ProgressPreference
        $global:ProgressPreference = 'SilentlyContinue'

        try {
            . $ScriptBlock
        }
        finally {
            $global:ProgressPreference = $prevProgressPreference
        }
    }
}

function InternetCheck {
    Clear-Host
    Write-Host "                  Created by shinthebean for PC Help Hub Discord"
    Write-Host "                 Any issues/queries contact shinthebean on Discord"
    Write-Host "             https://github.com/PC-Help-Hub/pchh-main/tree/main/scripts"
    Write-Host "                        Credits of inspiration to: jheden"
    Write-Host ""

    Write-Host "Testing for an internet connection.."
    try {
        Invoke-WithoutProgress {
            Invoke-WebRequest google.com -ErrorAction Stop > $null
            Write-Host "Network Connection detected! Continuing with script..."
        }
    }
    catch {
        Write-Host "No active Network Connection detected.." -ForegroundColor Red
        Write-Host "Unable to check for corruption.." -ForegroundColor Red
        IntegCheck
    }
    script
}

function script {
    Write-Host ""
    Write-Host "---------------------------------"
    Write-Host "        STARTING COMMANDS        "
    Write-Host "---------------------------------"
    Write-Host ""
    $scanprompt = Read-Host "Do you wish to do a thorough scan for corruption? (Y for thorough scan | N for quick scan)"

    if ($scanprompt -eq "Y" -or $scanprompt -eq "y") {
        Write-Host ""
        ThoroughScan
    }
    elseif ($scanprompt -eq "N" -or $scanprompt -eq "n") {
        Write-Host ""
        QuickScan
    }
    else {
        Write-Host "The option you have chosen isn't valid, press any key to go back to the menu."
        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") > $null
        InternetCheck
    }
}

function ThoroughScan {
    Write-Host "Performing a thorough scan.."
    Write-Host ""
    try {
        & "DISM.exe" "/Online" "/Cleanup-Image" "/ScanHealth" > $null
        $exitCode = $LASTEXITCODE
    }
    catch {
        Write-Host "There was an error while performing DISM ScanHealth" -ForegroundColor Red
        Write-Host "Retry the script or head to the discord and show them the error." -ForegroundColor Red
        eof
    }

    if ($exitCode -eq 0) {
        Write-Host "No file corruption detected, checking windows integrity.." -ForegroundColor Green
        IntegCheck
    }
    elseif ($exitCode -eq 1) {
        corruption
    }
    elseif ($exitCode -eq 2) {
        Write-Host "The scan has indicated that your windows image is not repairable and can only be fixed with a Windows Reinstall." -ForegroundColor Red
        Write-Host "Head to the PCHH discord for directions on how to reinstall windows." -ForegroundColor Red
        eof
    }
    else {
        corruption
    }
}

function QuickScan {
    Write-Host "Performing a quick scan.."
    Write-Host ""
    try {
        & "DISM.exe" "/Online" "/Cleanup-Image" "/CheckHealth" > $null
        $exitCode = $LASTEXITCODE
    }
    catch {
        Write-Host "There was an error while performing DISM CheckHealth" -ForegroundColor Red
        Write-Host "Retry the script or head to the discord and show them the error." -ForegroundColor Red
        eof
    }

    if ($exitCode -eq 0) {
        Write-Host "No file corruption detected, checking windows integrity.." -ForegroundColor Green
        IntegCheck
    }
    elseif ($exitCode -eq 1) {
        corruption
    }
    elseif ($exitCode -eq 2) {
        Write-Host "The scan has indicated that your windows image is not repairable and can only be fixed with a Windows Reinstall." -ForegroundColor Red
        Write-Host "Head to the PCHH discord for directions on how to reinstall windows." -ForegroundColor Red
        eof
    }
    else {
        corruption
    }
}

function corruption {
    Write-Host "Corruption Detected, pushing fix.."
    Write-Host "Keep in mind this will take some time to complete (~15 minutes depending on system specs)"
    Write-Host ""
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup > $null
    }
    catch {
        Write-Host "There was an error while performing StartComponentCleanup" -ForegroundColor Red
        Write-Host "Retry the script or head to the discord and show them the error." -ForegroundColor Red
        eof
    }
    Write-Host "1/2 Complete"
    try {
        DISM /Online /Cleanup-Image /RestoreHealth > $null
    }
    catch {
        Write-Host "There was an error while performing RestoreHealth" -ForegroundColor Red
        Write-Host "Retry the script or head to the discord and show them the error." -ForegroundColor Red
        eof
    }
    Write-Host "2/2 Complete"
    Write-Host ""
    IntegCheck
}

function IntegCheck {
    Write-Host ""
    Write-Host "Checking file integrity.."
    Write-Host ""

    $windowsDriveLetter = (Get-WmiObject -Query "SELECT * FROM Win32_OperatingSystem").SystemDrive

    $disks = Get-PhysicalDisk
    
    $timeoutSeconds = 0
    
    foreach ($disk in $disks) {
        $partitions = Get-Partition -DiskNumber $disk.DeviceId
    
        foreach ($partition in $partitions) {
            $volumes = Get-Volume -Partition $partition
            foreach ($volume in $volumes) {
                if ($volume.DriveLetter -eq $windowsDriveLetter.TrimEnd(':')) {
                    $mediaType = $disk.MediaType
    
                    if ($mediaType -eq 'SSD') {
                        $timeoutSeconds = 1200
                    }
                    elseif ($mediaType -eq 'HDD') {
                        $timeoutSeconds = 2700
                    }
                    else {
                        $timeoutSeconds = 900
                    }
                    
                    break
                }
            }
        }
    }

    $random = Get-Random -Minimum 1 -Maximum 1000

    Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -NoNewWindow -Wait -RedirectStandardError "$env:TEMP\sfcerror_$random.txt" -RedirectStandardOutput "$env:TEMP\sfcoutput.txt"

    Remove-Item "$env:TEMP\sfcerror.txt" -Force > $null 2>&1
    Remove-Item "$env:TEMP\sfcoutput.txt" -Force > $null 2>&1

    $startTime = Get-Date

    while ($true) {
        Start-Sleep -Seconds 1
        $runningTime = (Get-Date) - $startTime

        if ($runningTime.TotalSeconds -gt $timeoutSeconds) {
            Timeout
            break
        }

        $sfcProcess = Get-Process -Name "sfc" -ErrorAction SilentlyContinue
        if ($null -eq $sfcProcess) {
            $exitCode = $LASTEXITCODE

            if ($exitCode -eq 0) {
                Write-Host "Windows has found no corruption." -ForegroundColor Green
                eof
            }
            elseif ($exitCode -eq 1) {
                Write-Host "Windows has detected corruption and has successfully repaired it!" -ForegroundColor Green
                Write-Host "It is recommended to restart your computer for the changes to apply correctly." -ForegroundColor Green
                Write-Host "Press OK on the prompt to restart your PC." -ForegroundColor Green
                restart
            }
            elseif ($exitCode -eq 2) {
                Write-Host "Windows has detected corruption but was unable to repair it, a reinstallation of Windows is needed to repair these files." -ForegroundColor Red
                eof
            }
            else {
                Write-Host "There was an output of SFC that isn't common, let's perform a restart of your computer." -ForegroundColor Yellow   
                restart
            }
            break
        }
    }
}

function Timeout {
    Write-Host "The SFC scan has exceeded the expected timeout duration." -ForegroundColor Yellow
    Write-Host "You will need to restart your computer and manually open Command Prompt or PowerShell as an Administrator and run 'sfc /scannow'." -ForegroundColor Yellow
    eof
}

function eof {
    Write-Host ""
    Write-Host "Press any key to exit the script!"
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") > $null
    exit
}

function unexpecterror {
    Clear-Host
    Write-Host "An unexpected result that isn't written to the script has occurred!"
    Write-Host "Ping @shinthebean for this issue, do not exit the script."
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") > $null
    unexpecterror
}

function restart {
    Add-Type -AssemblyName PresentationFramework; 
    $result = [System.Windows.MessageBox]::Show('A restart is required in order for Windows to apply the made changes correctly. Press OK to restart your computer.', 'Restart Confirmation', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning); 
    if ($result -eq [System.Windows.MessageBoxResult]::OK) { shutdown /r /t 0 }
    pause > $null
}

InternetCheck
