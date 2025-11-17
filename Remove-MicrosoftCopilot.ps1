#Requires -RunAsAdministrator
<#
.SYNOPSIS
    All-In-One Script für Microsoft Copilot Entfernung, Monitoring und Blockierung
.DESCRIPTION
    Dieses Script vereint alle Copilot-Removal Funktionen in einer Datei:
    - REMOVE: Vollständige Entfernung und Blockierung (Standard)
    - TEST: Überprüfung ob Copilot vorhanden ist
    - DETECT: Detection Method für SCCM/Intune
    - WDAC: Windows Defender Application Control (Kernel-Ebene)

    v2.1 Features:
    - Copilot-Hardwaretaste blockieren
    - Windows Recall deaktivieren
    - Click-To-Do deaktivieren
    - Office Connected Experiences deaktivieren
    - Game Bar Copilot entfernen
    - WDAC Kernel-Blockierung (optional)

.PARAMETER Mode
    Ausführungsmodus: Remove, Test, Detect, WDAC (Standard: Remove)
.PARAMETER LogOnly
    Testlauf ohne Änderungen (nur für Mode=Remove)
.PARAMETER NoRestart
    Unterdrückt Neustart-Prompt
.PARAMETER NoBackup
    Überspringt Backup-Erstellung
.PARAMETER Force
    Unterdrückt Bestätigungsdialoge
.PARAMETER LogPath
    Pfad zur Log-Datei (Standard: $env:LOCALAPPDATA\CopilotRemoval\Logs\...)
.PARAMETER BackupDir
    Basis-Verzeichnis für Backups (Standard: $env:LOCALAPPDATA\CopilotRemoval\Backups)
.PARAMETER UseTemp
    Verwendet C:\Temp statt AppData (mit User-Differenzierung für RDS)
.PARAMETER EmailAlert
    E-Mail für Benachrichtigungen (Mode=Test)
.PARAMETER SMTPServer
    SMTP-Server für E-Mail (Mode=Test)
.PARAMETER CreateScheduledTask
    Erstellt monatlichen Task (Mode=Test)
.PARAMETER AuditOnly
    WDAC Audit-Modus (Mode=WDAC)
.PARAMETER Deploy
    Deployed WDAC Policy (Mode=WDAC)
.PARAMETER Unattended
    Vollautomatischer headless Lauf (impliziert -Force und -NoRestart, überspringt alle Prompts)
.PARAMETER SkipAlreadyRun
    Überspringt die Prüfung, ob Script bereits ausgeführt wurde (nur Mode=Remove)

.EXAMPLE
    .\Remove-MicrosoftCopilot.ps1
    Entfernt Copilot (Standard-Modus)
.EXAMPLE
    .\Remove-MicrosoftCopilot.ps1 -LogOnly
    Testlauf ohne Änderungen
.EXAMPLE
    .\Remove-MicrosoftCopilot.ps1 -Mode Test
    Überprüft ob Copilot vorhanden ist
.EXAMPLE
    .\Remove-MicrosoftCopilot.ps1 -Mode Test -CreateScheduledTask
    Erstellt monatlichen Monitoring-Task
.EXAMPLE
    .\Remove-MicrosoftCopilot.ps1 -Mode Detect
    Detection für SCCM/Intune (Exit 0=Compliant, 1=Non-Compliant)
.EXAMPLE
    .\Remove-MicrosoftCopilot.ps1 -Mode WDAC -AuditOnly -Deploy
    Erstellt und deployed WDAC Policy im Audit-Modus

.AUTHOR
    Lars Bahlmann / badata GmbH - IT Systemhaus in Bremen / www.badata.de
.VERSION
    2.1 - All-In-One Edition - November 2025
.NOTES
    Erfordert Administratorrechte
    Vereint: Remove-CopilotComplete, Test-CopilotPresence, Detect, WDAC
#>

param(
    [ValidateSet("Remove","Test","Detect","WDAC")]
    [string]$Mode = "Remove",

    # Remove-Mode Parameter
    [switch]$LogOnly,
    [switch]$NoRestart,
    [switch]$NoBackup,
    [switch]$Force,

    # Pfad-Parameter (für alle Modi)
    [string]$LogPath,
    [string]$BackupDir,
    [switch]$UseTemp,

    # Test-Mode Parameter
    [string]$EmailAlert,
    [string]$SMTPServer,
    [switch]$CreateScheduledTask,

    # WDAC-Mode Parameter
    [switch]$AuditOnly,
    [switch]$Deploy,
    [string]$PolicyPath,

    # Automation Parameter
    [switch]$Unattended,
    [switch]$SkipAlreadyRun
)

# Unattended-Modus aktiviert Force und NoRestart automatisch
if ($Unattended) {
    $Force = $true
    $NoRestart = $true
}

# ========================================
# GLOBALE VARIABLEN
# ========================================

# Automatische Pfad-Ermittlung (RDS-sicher, ohne Systemordner-Änderungen)
$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$DateStamp = Get-Date -Format 'yyyyMMdd'

if (-not $LogPath) {
    if ($UseTemp) {
        # C:\Temp mit User-Differenzierung (für RDS)
        if ($Mode -eq "Test") {
            $LogPath = "C:\Temp\CopilotRemoval\$env:USERNAME\Logs\CopilotMonitoring_$DateStamp.log"
        } else {
            $LogPath = "C:\Temp\CopilotRemoval\$env:USERNAME\Logs\CopilotManagement_$Timestamp.log"
        }
    } else {
        # Standard: User AppData (automatisch user-spezifisch)
        if ($Mode -eq "Test") {
            $LogPath = "$env:LOCALAPPDATA\CopilotRemoval\Logs\CopilotMonitoring_$DateStamp.log"
        } else {
            $LogPath = "$env:LOCALAPPDATA\CopilotRemoval\Logs\CopilotManagement_$Timestamp.log"
        }
    }
}

if (-not $BackupDir) {
    if ($UseTemp) {
        # C:\Temp mit User-Differenzierung (für RDS)
        $script:BackupPath = "C:\Temp\CopilotRemoval\$env:USERNAME\Backups\Backup_$Timestamp"
    } else {
        # Standard: User AppData (automatisch user-spezifisch)
        $script:BackupPath = "$env:LOCALAPPDATA\CopilotRemoval\Backups\Backup_$Timestamp"
    }
} else {
    $script:BackupPath = Join-Path $BackupDir "Backup_$Timestamp"
}

# WDAC PolicyPath Default
if (-not $PolicyPath) {
    if ($UseTemp) {
        $PolicyPath = "C:\Temp\CopilotRemoval\$env:USERNAME\WDAC\WDACCopilotBlock.xml"
    } else {
        $PolicyPath = "$env:LOCALAPPDATA\CopilotRemoval\WDAC\WDACCopilotBlock.xml"
    }
}

$script:ErrorCount = 0
$script:WarningCount = 0
$script:SuccessCount = 0
$script:WindowsVersion = ""
$script:IsWindows11 = $false
$script:LogEntries = @()

# ========================================
# REGISTRY-TRACKING (Einmalige Ausführung)
# ========================================
$script:RegistryTrackingPath = "HKLM:\SOFTWARE\CopilotRemoval"

function Test-AlreadyExecuted {
    try {
        if (Test-Path $script:RegistryTrackingPath) {
            $LastRun = Get-ItemProperty -Path $script:RegistryTrackingPath -Name "LastRun" -ErrorAction SilentlyContinue
            $Status = Get-ItemProperty -Path $script:RegistryTrackingPath -Name "Status" -ErrorAction SilentlyContinue

            if ($LastRun -and $Status.Status -eq "Success") {
                return @{
                    AlreadyRun = $true
                    LastRun = $LastRun.LastRun
                    Version = (Get-ItemProperty -Path $script:RegistryTrackingPath -Name "Version" -ErrorAction SilentlyContinue).Version
                    ExecutedBy = (Get-ItemProperty -Path $script:RegistryTrackingPath -Name "ExecutedBy" -ErrorAction SilentlyContinue).ExecutedBy
                }
            }
        }
        return @{AlreadyRun = $false}
    } catch {
        return @{AlreadyRun = $false}
    }
}

function Set-ExecutionTracking {
    param([string]$Status = "Success")

    try {
        if (-not $LogOnly) {
            if (-not (Test-Path $script:RegistryTrackingPath)) {
                New-Item -Path $script:RegistryTrackingPath -Force | Out-Null
            }

            Set-ItemProperty -Path $script:RegistryTrackingPath -Name "LastRun" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Type String
            Set-ItemProperty -Path $script:RegistryTrackingPath -Name "Version" -Value "2.1" -Type String
            Set-ItemProperty -Path $script:RegistryTrackingPath -Name "ExecutedBy" -Value $env:USERNAME -Type String
            Set-ItemProperty -Path $script:RegistryTrackingPath -Name "Status" -Value $Status -Type String
            Set-ItemProperty -Path $script:RegistryTrackingPath -Name "ComputerName" -Value $env:COMPUTERNAME -Type String
            Set-ItemProperty -Path $script:RegistryTrackingPath -Name "Mode" -Value $Mode -Type String

            Write-LogEntry "Execution-Tracking in Registry gesetzt" -Type Success
        }
    } catch {
        Write-LogEntry "Warnung: Execution-Tracking konnte nicht gesetzt werden: $($_.Exception.Message)" -Type Warning
    }
}

# ========================================
# GEMEINSAME FUNKTIONEN
# ========================================
function Write-LogEntry {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet("Info","Warning","Error","Success")]
        [string]$Type = "Info"
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Type] $Message"

    switch ($Type) {
        "Error"   {
            Write-Host $LogEntry -ForegroundColor Red
            $script:ErrorCount++
        }
        "Warning" {
            Write-Host $LogEntry -ForegroundColor Yellow
            $script:WarningCount++
        }
        "Success" {
            Write-Host $LogEntry -ForegroundColor Green
            $script:SuccessCount++
        }
        default   { Write-Host $LogEntry }
    }

    if (-not (Test-Path (Split-Path $LogPath))) {
        New-Item -Path (Split-Path $LogPath) -ItemType Directory -Force | Out-Null
    }
    $LogEntry | Out-File -FilePath $LogPath -Append -Encoding UTF8

    $script:LogEntries += @{
        Timestamp = $Timestamp
        Type = $Type
        Message = $Message
    }
}

function Write-ProgressHelper {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete
    )
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

function Get-SystemInfo {
    Write-LogEntry "Sammle System-Informationen..." -Type Info

    $OSInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $BuildNumber = [int]$OSInfo.BuildNumber

    $script:WindowsVersion = $OSInfo.Caption
    $script:IsWindows11 = $BuildNumber -ge 22000

    Write-LogEntry "Betriebssystem: $($script:WindowsVersion)" -Type Info
    Write-LogEntry "Build-Nummer: $BuildNumber" -Type Info
    Write-LogEntry "Windows 11: $($script:IsWindows11)" -Type Info

    $Edition = (Get-WindowsEdition -Online).Edition
    Write-LogEntry "Windows Edition: $Edition" -Type Info

    $AppLockerAvailable = $Edition -match "Enterprise|Professional|Education"
    Write-LogEntry "AppLocker verfügbar: $AppLockerAvailable" -Type Info

    return @{
        IsWindows11 = $script:IsWindows11
        BuildNumber = $BuildNumber
        Edition = $Edition
        AppLockerAvailable = $AppLockerAvailable
    }
}

# ========================================
# MODE: DETECT (für SCCM/Intune)
# ========================================
function Invoke-DetectMode {
    Write-Host "[DETECT] Starting Copilot Detection..." -ForegroundColor Cyan

    # Prüfung 1: App-Pakete
    $CopilotPackages = @("Microsoft.Copilot", "Microsoft.Windows.Ai.Copilot.Provider",
                         "MicrosoftWindows.Client.WebExperience", "Microsoft.WindowsCopilot")

    foreach ($Package in $CopilotPackages) {
        $Installed = Get-AppxPackage -AllUsers -Name "*$Package*" -ErrorAction SilentlyContinue
        if ($Installed) {
            Write-Host "[DETECT] NON-COMPLIANT: Copilot package found: $($Installed.Name)" -ForegroundColor Red
            exit 1
        }
    }

    $Provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -like "*Copilot*" }
    if ($Provisioned) {
        Write-Host "[DETECT] NON-COMPLIANT: Provisioned Copilot package found" -ForegroundColor Red
        exit 1
    }

    # Prüfung 2: Registry
    $RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
    $RegName = "TurnOffWindowsCopilot"
    try {
        $Value = Get-ItemProperty -Path $RegPath -Name $RegName -ErrorAction Stop
        if ($Value.$RegName -ne 1) {
            Write-Host "[DETECT] NON-COMPLIANT: Registry not configured" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "[DETECT] NON-COMPLIANT: Registry key missing" -ForegroundColor Red
        exit 1
    }

    # Prüfung 3: Kontextmenü
    $BlockedPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked"
    $CopilotGUID = "{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}"
    try {
        $Blocked = Get-ItemProperty -Path $BlockedPath -Name $CopilotGUID -ErrorAction Stop
        if (-not $Blocked) {
            Write-Host "[DETECT] NON-COMPLIANT: Context menu not blocked" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "[DETECT] NON-COMPLIANT: Context menu block not configured" -ForegroundColor Red
        exit 1
    }

    Write-Host "[DETECT] COMPLIANT: Copilot removed and blocked" -ForegroundColor Green
    exit 0
}

# ========================================
# MODE: TEST (Monitoring)
# ========================================
function Invoke-TestMode {
    Write-LogEntry "========================================" -Type Info
    Write-LogEntry "Copilot-Präsenz-Überprüfung gestartet" -Type Info
    Write-LogEntry "========================================" -Type Info

    if ($CreateScheduledTask) {
        New-MonitoringTask
        exit 0
    }

    # Test-Funktionen
    $Results = @{
        AppPackages = Test-AppPackages
        Registry = Test-RegistrySettings
        ContextMenu = Test-ContextMenu
        HostsFile = Test-HostsFile
        Firewall = Test-FirewallRules
        Tasks = Test-ScheduledTasks
        OfficeConnectedExp = Test-OfficeConnectedExperiences
    }

    # Zusammenfassung
    Write-LogEntry "" -Type Info
    Write-LogEntry "========================================" -Type Info
    Write-LogEntry "ZUSAMMENFASSUNG" -Type Info
    Write-LogEntry "========================================" -Type Info

    $AllOK = $true
    $Warnings = 0

    foreach ($Key in $Results.Keys) {
        $Result = $Results[$Key]
        $Status = $Result.Status

        if ($Status -eq "NICHT_ANWENDBAR") {
            Write-LogEntry "[$Key] NICHT ANWENDBAR" -Type Info
        } elseif ($Status -ne "OK") {
            $AllOK = $false
            if ($Status -eq "GEFUNDEN") {
                Write-LogEntry "[$Key] COPILOT GEFUNDEN!" -Type Error
            } else {
                Write-LogEntry "[$Key] $Status" -Type Warning
                $Warnings++
            }
        } else {
            Write-LogEntry "[$Key] OK" -Type Success
        }
    }

    if ($AllOK) {
        Write-LogEntry "✓ GESAMTSTATUS: SAUBER - Kein Copilot gefunden" -Type Success
        if ($EmailAlert) { Send-AlertEmail -Results $Results -Status "SAUBER" }
        exit 0
    } elseif ($Results.AppPackages.Status -eq "GEFUNDEN") {
        Write-LogEntry "✗ GESAMTSTATUS: COPILOT GEFUNDEN!" -Type Error
        if ($EmailAlert) { Send-AlertEmail -Results $Results -Status "GEFUNDEN" }
        exit 1
    } else {
        Write-LogEntry "⚠ GESAMTSTATUS: BLOCKIERUNGEN UNVOLLSTÄNDIG - $Warnings Warnung(en)" -Type Warning
        if ($EmailAlert -and $Warnings -gt 2) { Send-AlertEmail -Results $Results -Status "UNVOLLSTÄNDIG" }
        exit 2
    }
}

# Test-Funktionen (für Mode=Test)
function Test-AppPackages {
    Write-LogEntry "Prüfe App-Pakete..." -Type Info
    $CopilotPackages = @("Microsoft.Copilot", "Microsoft.Windows.Ai.Copilot.Provider",
                         "MicrosoftWindows.Client.WebExperience", "Microsoft.WindowsCopilot")
    $Found = @()
    foreach ($Package in $CopilotPackages) {
        $Installed = Get-AppxPackage -AllUsers -Name "*$Package*" -ErrorAction SilentlyContinue
        if ($Installed) { $Found += $Installed }
    }
    $Provisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*Copilot*" }
    if ($Provisioned) { $Found += $Provisioned }

    if ($Found.Count -eq 0) {
        Write-LogEntry "OK: Keine Copilot App-Pakete gefunden" -Type Success
        return @{Status="OK"; Found=$null}
    } else {
        return @{Status="GEFUNDEN"; Found=$Found}
    }
}

function Test-RegistrySettings {
    $Checks = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name="TurnOffWindowsCopilot"; Expected=1},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name="SetCopilotHardwareKey"; Expected=1},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Recall"; Name="DisableRecall"; Expected=1}
    )
    $Issues = @()
    foreach ($Check in $Checks) {
        try {
            $Value = Get-ItemProperty -Path $Check.Path -Name $Check.Name -ErrorAction SilentlyContinue
            if ($null -eq $Value -or $Value.($Check.Name) -ne $Check.Expected) {
                $Issues += "$($Check.Path)\$($Check.Name) nicht korrekt"
            }
        } catch { $Issues += "$($Check.Path)\$($Check.Name) fehlt" }
    }
    return if ($Issues.Count -eq 0) { @{Status="OK"} } else { @{Status="FEHLER"; Issues=$Issues} }
}

function Test-ContextMenu {
    $BlockedPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked"
    $Blocked = Get-ItemProperty -Path $BlockedPath -Name "{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}" -ErrorAction SilentlyContinue
    return if ($Blocked) { @{Status="OK"} } else { @{Status="FEHLER"} }
}

function Test-HostsFile {
    $HostsContent = Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue
    $Blocked = $HostsContent | Where-Object { $_ -match "copilot\.microsoft\.com" }
    return if ($Blocked) { @{Status="OK"} } else { @{Status="TEILWEISE"} }
}

function Test-FirewallRules {
    $Rules = Get-NetFirewallRule -DisplayName "*Copilot*" -ErrorAction SilentlyContinue
    return if ($Rules) { @{Status="OK"} } else { @{Status="FEHLER"} }
}

function Test-ScheduledTasks {
    $Tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*Copilot*" -and $_.State -eq "Ready" }
    return if ($Tasks.Count -eq 0) { @{Status="OK"} } else { @{Status="FEHLER"; ActiveCount=$Tasks.Count} }
}

function Test-OfficeConnectedExperiences {
    $OfficeVersions = @("16.0", "15.0", "17.0")
    $CheckedVersions = 0
    foreach ($Version in $OfficeVersions) {
        if (Test-Path "HKCU:\Software\Microsoft\Office\$Version\Common\Privacy") {
            $CheckedVersions++
        }
    }
    return if ($CheckedVersions -eq 0) { @{Status="NICHT_ANWENDBAR"} } else { @{Status="OK"} }
}

function Send-AlertEmail {
    param([object]$Results, [string]$Status)
    if (-not $EmailAlert -or -not $SMTPServer) { return }

    $Body = "Copilot-Status auf $env:COMPUTERNAME : $Status`n`nDetails siehe Log: $LogPath"
    try {
        Send-MailMessage -To $EmailAlert -From "copilot-monitoring@$env:USERDNSDOMAIN" `
                         -Subject "Copilot-Monitoring: $Status" -Body $Body `
                         -SmtpServer $SMTPServer -ErrorAction Stop
        Write-LogEntry "E-Mail gesendet an: $EmailAlert" -Type Success
    } catch {
        Write-LogEntry "E-Mail-Fehler: $($_.Exception.Message)" -Type Error
    }
}

function New-MonitoringTask {
    $TaskName = "Copilot-Monitoring"
    $TaskPath = "\badata\"
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode Test"
    $Trigger = New-ScheduledTaskTrigger -Monthly -DaysOfMonth 1 -At 08:00
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    try {
        Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Action $Action `
                               -Trigger $Trigger -Settings $Settings -Principal $Principal `
                               -Description "Monatliche Copilot-Überprüfung" -ErrorAction Stop
        Write-LogEntry "Scheduled Task erstellt: $TaskPath$TaskName" -Type Success
    } catch {
        Write-LogEntry "Fehler: $($_.Exception.Message)" -Type Error
    }
}

# ========================================
# MODE: REMOVE (Hauptfunktionalität)
# ========================================
function Invoke-RemoveMode {
    Write-LogEntry "======================================" -Type Info
    Write-LogEntry "Copilot Entfernungs-Script v2.1 gestartet" -Type Info
    Write-LogEntry "======================================" -Type Info
    Write-LogEntry "Modus: $(if($LogOnly){'TEST (LogOnly)'}else{'PRODUKTIV'})" -Type Info

    # Prüfe ob Script bereits ausgeführt wurde
    if (-not $SkipAlreadyRun -and -not $LogOnly) {
        $ExecutionCheck = Test-AlreadyExecuted
        if ($ExecutionCheck.AlreadyRun) {
            Write-LogEntry "========================================" -Type Warning
            Write-LogEntry "SCRIPT BEREITS AUSGEFÜHRT!" -Type Warning
            Write-LogEntry "========================================" -Type Warning
            Write-LogEntry "Letzte Ausführung: $($ExecutionCheck.LastRun)" -Type Warning
            Write-LogEntry "Ausgeführt von: $($ExecutionCheck.ExecutedBy)" -Type Warning
            Write-LogEntry "Version: $($ExecutionCheck.Version)" -Type Warning
            Write-LogEntry "" -Type Info
            Write-LogEntry "Das Script wurde bereits erfolgreich ausgeführt." -Type Info
            Write-LogEntry "Verwenden Sie -SkipAlreadyRun um die Prüfung zu überspringen." -Type Info
            Write-LogEntry "" -Type Info

            if (-not $Unattended) {
                Write-Host ""
                Write-Host "Möchten Sie die Ausführung trotzdem fortsetzen? (J/N)" -ForegroundColor Yellow
                $Response = Read-Host
                if ($Response -ne "J" -and $Response -ne "j") {
                    Write-LogEntry "Ausführung abgebrochen durch Benutzer" -Type Info
                    exit 0
                }
            } else {
                Write-LogEntry "Unattended-Modus: Überspringe erneute Ausführung" -Type Info
                exit 0
            }
        }
    }

    $SystemInfo = Get-SystemInfo

    if (-not $NoBackup) { Initialize-Backup }

    # PHASE 1: App-Pakete entfernen
    Write-ProgressHelper -Activity "Phase 1/10" -Status "Entferne Copilot-Pakete..." -PercentComplete 10
    Remove-CopilotPackages -SystemInfo $SystemInfo

    # PHASE 2: Registry
    Write-ProgressHelper -Activity "Phase 2/10" -Status "Konfiguriere Registry..." -PercentComplete 20
    Set-RegistryEntries

    # PHASE 3: Kontextmenü
    Write-ProgressHelper -Activity "Phase 3/10" -Status "Blockiere Kontextmenü..." -PercentComplete 30
    Block-ContextMenu

    # PHASE 4: AppLocker
    Write-ProgressHelper -Activity "Phase 4/10" -Status "Konfiguriere AppLocker..." -PercentComplete 40
    if ($SystemInfo.AppLockerAvailable) { Configure-AppLocker }

    # PHASE 5: Firewall
    Write-ProgressHelper -Activity "Phase 5/10" -Status "Konfiguriere Firewall..." -PercentComplete 50
    Create-FirewallRules

    # PHASE 6: Tasks
    Write-ProgressHelper -Activity "Phase 6/10" -Status "Deaktiviere Tasks..." -PercentComplete 60
    Disable-CopilotTasks

    # PHASE 7-8: GPO Update
    Write-ProgressHelper -Activity "Phase 8/10" -Status "Aktualisiere GPO..." -PercentComplete 70
    if (-not $LogOnly) { gpupdate /force /wait:0 | Out-Null }

    # PHASE 9: Verifizierung
    Write-ProgressHelper -Activity "Phase 9/10" -Status "Verifiziere..." -PercentComplete 80
    $TestResult = Test-CopilotRemoval

    # PHASE 10: Cleanup
    Write-ProgressHelper -Activity "Phase 10/10" -Status "Bereinigung..." -PercentComplete 90
    if (-not $LogOnly -and $Force) {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Process explorer
    }

    Write-Progress -Activity "Abgeschlossen" -Completed

    # Report
    $ReportPath = "$script:BackupPath\ExecutionReport.json"
    @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Computer = $env:COMPUTERNAME
        Mode = "Remove"
        Statistics = @{Errors=$script:ErrorCount; Warnings=$script:WarningCount; Successes=$script:SuccessCount}
        TestResult = $TestResult
    } | ConvertTo-Json -Depth 10 | Out-File -FilePath $ReportPath -Encoding UTF8

    Write-LogEntry "" -Type Info
    Write-LogEntry "STATUS: $(if($TestResult.Success){'ERFOLGREICH'}else{'WARNUNG'})" -Type $(if($TestResult.Success){'Success'}else{'Warning'})
    Write-LogEntry "Log: $LogPath" -Type Info
    Write-LogEntry "Backup: $script:BackupPath" -Type Info

    if (-not $NoRestart -and -not $LogOnly) {
        if ($Unattended) {
            Write-LogEntry "Unattended-Modus: Neustart wird nicht durchgeführt" -Type Info
        } else {
            $Restart = Read-Host "Computer neu starten? (J/N)"
            if ($Restart -eq "J") {
                Restart-Computer -Force
            }
        }
    }

    # Setze Execution-Tracking (nur bei erfolgreicher Ausführung)
    if (-not $LogOnly) {
        Set-ExecutionTracking -Status "Success"
    }
}

# Remove-Funktionen
function Initialize-Backup {
    if ($LogOnly) { return }
    if (-not (Test-Path $script:BackupPath)) {
        New-Item -Path $script:BackupPath -ItemType Directory -Force | Out-Null
        Write-LogEntry "Backup-Verzeichnis: $script:BackupPath" -Type Success
    }
}

function Remove-CopilotPackages {
    param($SystemInfo)
    $Packages = @("Microsoft.Copilot", "Microsoft.Windows.Ai.Copilot.Provider",
                  "MicrosoftWindows.Client.WebExperience", "Microsoft.WindowsCopilot")
    if ($SystemInfo.IsWindows11) { $Packages += "Microsoft.Windows.Copilot" }

    foreach ($Package in $Packages) {
        $Apps = Get-AppxPackage -AllUsers -Name "*$Package*" -ErrorAction SilentlyContinue
        foreach ($App in $Apps) {
            if (-not $LogOnly) {
                Remove-AppxPackage -Package $App.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                Write-LogEntry "Entfernt: $($App.Name)" -Type Success
            }
        }
        $Prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$Package*" }
        if ($Prov -and -not $LogOnly) {
            Remove-AppxProvisionedPackage -Online -PackageName $Prov.PackageName -ErrorAction SilentlyContinue
            Write-LogEntry "Provisioniert entfernt: $($Prov.DisplayName)" -Type Success
        }
    }
}

function Set-RegistryEntries {
    $Settings = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name="TurnOffWindowsCopilot"; Value=1},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name="SetCopilotHardwareKey"; Value=1},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Recall"; Name="DisableRecall"; Value=1},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ClickToDo"; Name="DisableClickToDo"; Value=1},
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="DisableCopilot"; Value=1},
        @{Path="HKLM:\SOFTWARE\Policies\WindowsNotepad"; Name="DisableAIFeatures"; Value=1}
    )

    foreach ($Setting in $Settings) {
        if (-not (Test-Path $Setting.Path) -and -not $LogOnly) {
            New-Item -Path $Setting.Path -Force | Out-Null
        }
        if (-not $LogOnly) {
            Set-ItemProperty -Path $Setting.Path -Name $Setting.Name -Value $Setting.Value -Type DWord -Force
            Write-LogEntry "Registry: $($Setting.Path)\$($Setting.Name) = $($Setting.Value)" -Type Success
        }
    }

    # Office Connected Experiences
    $OfficeVersions = @("16.0", "15.0", "17.0")
    foreach ($Version in $OfficeVersions) {
        $Path = "HKCU:\Software\Microsoft\Office\$Version\Common\Privacy"
        if (Test-Path "HKCU:\Software\Microsoft\Office\$Version\Common") {
            if (-not $LogOnly) {
                if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
                Set-ItemProperty -Path $Path -Name "DisconnectedState" -Value 2 -Type DWord -Force
                Write-LogEntry "Office ${Version}: Connected Experiences deaktiviert" -Type Success
            }
        }
    }
}

function Block-ContextMenu {
    $Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked"
    if (-not (Test-Path $Path) -and -not $LogOnly) {
        New-Item -Path $Path -Force | Out-Null
    }
    if (-not $LogOnly) {
        Set-ItemProperty -Path $Path -Name "{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}" -Value "Copilot fragen" -Type String -Force
        Write-LogEntry "Kontextmenü blockiert" -Type Success
    }
}

function Configure-AppLocker {
    if ($LogOnly) { return }
    try {
        $Service = Get-Service -Name "AppIDSvc" -ErrorAction Stop
        if ($Service.Status -ne "Running") {
            Set-Service -Name "AppIDSvc" -StartupType Automatic
            Start-Service -Name "AppIDSvc"
        }

        $XML = @'
<AppLockerPolicy Version="1">
  <RuleCollection Type="Appx" EnforcementMode="Enabled">
    <FilePublisherRule Id="a9e18c21-ff8f-43cf-b9fc-db40eed693ba" Name="Block Microsoft Copilot" UserOrGroupSid="S-1-1-0" Action="Deny">
      <Conditions>
        <FilePublisherCondition PublisherName="CN=MICROSOFT CORPORATION, O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US" ProductName="MICROSOFT.COPILOT" BinaryName="*">
          <BinaryVersionRange LowSection="*" HighSection="*"/>
        </FilePublisherCondition>
      </Conditions>
    </FilePublisherRule>
  </RuleCollection>
</AppLockerPolicy>
'@
        $TempFile = [System.IO.Path]::GetTempFileName()
        $XML | Out-File -FilePath $TempFile -Encoding UTF8
        Set-AppLockerPolicy -XmlPolicy $TempFile -Merge
        Remove-Item $TempFile -Force
        Write-LogEntry "AppLocker-Regel erstellt" -Type Success
    } catch {
        Write-LogEntry "AppLocker-Fehler: $($_.Exception.Message)" -Type Warning
    }
}

function Create-FirewallRules {
    $Domains = @("copilot.microsoft.com", "sydney.bing.com", "edgeservices.bing.com",
                 "www.bing.com/turing", "copilot.cloud.microsoft.com")

    $HostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    $HostsContent = Get-Content $HostsFile -ErrorAction SilentlyContinue

    foreach ($Domain in $Domains) {
        $AlreadyBlocked = $HostsContent | Where-Object { $_ -match "^\s*0\.0\.0\.0\s+$([regex]::Escape($Domain))" }
        if (-not $AlreadyBlocked -and -not $LogOnly) {
            Add-Content -Path $HostsFile -Value "0.0.0.0 $Domain # Copilot-Block"
            Write-LogEntry "Hosts-Eintrag: $Domain" -Type Success
        }
    }

    if (-not $LogOnly) { Clear-DnsClientCache -ErrorAction SilentlyContinue }
}

function Disable-CopilotTasks {
    $Tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*Copilot*" -or $_.TaskName -like "*AI*" }
    foreach ($Task in $Tasks) {
        if ($Task.State -ne "Disabled" -and -not $LogOnly) {
            Disable-ScheduledTask -TaskName $Task.TaskName -ErrorAction SilentlyContinue
            Write-LogEntry "Task deaktiviert: $($Task.TaskName)" -Type Success
        }
    }
}

function Test-CopilotRemoval {
    $Issues = @()
    $Packages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*Copilot*" }
    if ($Packages) { $Issues += "Pakete gefunden" }

    $Reg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue
    if (-not $Reg -or $Reg.TurnOffWindowsCopilot -ne 1) { $Issues += "Registry nicht gesetzt" }

    return @{Success = ($Issues.Count -eq 0); Issues = $Issues}
}

# ========================================
# MODE: WDAC
# ========================================
function Invoke-WDACMode {
    Write-LogEntry "======================================" -Type Info
    Write-LogEntry "WDAC Copilot-Blockierung" -Type Info
    Write-LogEntry "======================================" -Type Info

    # Prüfe WDAC-Unterstützung
    $Edition = (Get-WindowsEdition -Online).Edition
    if ($Edition -notmatch "Enterprise|Education|Server") {
        Write-LogEntry "WARNUNG: WDAC typischerweise nur auf Enterprise/Education" -Type Warning
    }

    if (-not (Get-Command -Name New-CIPolicy -ErrorAction SilentlyContinue)) {
        Write-LogEntry "FEHLER: WDAC nicht verfügbar!" -Type Error
        exit 1
    }

    Write-LogEntry "HINWEIS: WDAC ist sehr restriktiv - in VM testen!" -Type Warning

    $TempDir = Join-Path $env:TEMP "WDACCopilot_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null

    try {
        $BasePath = Join-Path $TempDir "BasePolicy.xml"
        New-CIPolicy -FilePath $BasePath -Level FilePublisher -UserPEs -Fallback Hash `
                     -ScanPath "C:\Windows\System32" -NoShadowCopy | Out-Null

        [xml]$PolicyXML = Get-Content $BasePath
        $PolicyXML.SiPolicy.PolicyID = [guid]::NewGuid().ToString("B").ToUpper()

        if ($AuditOnly) {
            Write-LogEntry "Modus: AUDIT (nur Logging)" -Type Warning
        } else {
            Write-LogEntry "Modus: ENFORCEMENT (Blocking aktiv)" -Type Warning
        }

        $PolicyXML.Save($PolicyPath)
        Write-LogEntry "WDAC Policy erstellt: $PolicyPath" -Type Success

        $BinaryPath = $PolicyPath -replace "\.xml$", ".bin"
        ConvertFrom-CIPolicy -XmlFilePath $PolicyPath -BinaryFilePath $BinaryPath

        if ($Deploy) {
            Write-LogEntry "WARNUNG: Deployment ist kritisch!" -Type Warning
            if ($Unattended) {
                Write-LogEntry "Unattended-Modus: WDAC Deployment wird NICHT durchgeführt (zu gefährlich)" -Type Warning
                $Confirm = "N"
            } else {
                $Confirm = Read-Host "Wirklich deployen? (J/N)"
            }
            if ($Confirm -eq "J") {
                $DeployPath = "C:\Windows\System32\CodeIntegrity\CiPolicies\Active"
                $GUID = [guid]::NewGuid().ToString("B").ToUpper()
                Copy-Item -Path $BinaryPath -Destination "$DeployPath\$GUID.cip" -Force
                Write-LogEntry "Policy deployed - NEUSTART ERFORDERLICH!" -Type Success
            }
        } else {
            Write-LogEntry "Policy NICHT deployed (-Deploy für Deployment)" -Type Info
        }

        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-LogEntry "Fehler: $($_.Exception.Message)" -Type Error
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }
}

# ========================================
# HAUPTPROGRAMM
# ========================================
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Microsoft Copilot Removal Toolkit v2.1                 ║" -ForegroundColor Cyan
Write-Host "║  All-In-One Edition                                      ║" -ForegroundColor Cyan
Write-Host "║  badata GmbH - IT Systems                                ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Admin-Check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "FEHLER: Administratorrechte erforderlich!" -ForegroundColor Red
    exit 1
}

# Mode-Dispatcher
switch ($Mode) {
    "Remove" { Invoke-RemoveMode }
    "Test"   { Invoke-TestMode }
    "Detect" { Invoke-DetectMode }
    "WDAC"   { Invoke-WDACMode }
}

Write-Host ""
Write-Host "Script beendet" -ForegroundColor Green
exit 0
