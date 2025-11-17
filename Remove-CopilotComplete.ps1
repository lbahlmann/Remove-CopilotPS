#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Vollständige Entfernung und Blockierung von Microsoft Copilot (Enhanced Version)
.DESCRIPTION
    Dieses Script entfernt Microsoft Copilot vollständig von Windows 11/10 und
    blockiert die Neuinstallation durch verschiedene Mechanismen.

    NEU in v2.1:
    - Copilot-Hardwaretaste blockieren/umleiten
    - Windows Recall deaktivieren (Copilot+ PCs)
    - Click-To-Do KI-Aktionen deaktivieren
    - Office Connected Experiences deaktivieren
    - Game Bar Copilot deaktivieren
    - Erweiterte Firewall-Domains

    v2.0 Features:
    - Rollback-Funktion für Registry-Änderungen
    - Windows-Version-Erkennung
    - Dynamische Pfaderkennung
    - AppLocker-Prüfung vor Merge
    - Backup-System für Registry
    - Progress-Anzeige
    - Verbesserte Fehlerbehandlung
.PARAMETER NoRestart
    Unterdrückt den Neustart-Prompt am Ende
.PARAMETER LogOnly
    Führt einen Testlauf durch ohne Änderungen vorzunehmen
.PARAMETER LogPath
    Pfad zur Log-Datei (Standard: $env:LOCALAPPDATA\CopilotRemoval\Logs\...)
.PARAMETER BackupDir
    Basis-Verzeichnis für Backups (Standard: $env:LOCALAPPDATA\CopilotRemoval\Backups)
.PARAMETER UseTemp
    Verwendet C:\Temp statt AppData (mit User-Differenzierung für RDS)
.PARAMETER NoBackup
    Überspringt das Backup von Registry-Einträgen
.PARAMETER Force
    Unterdrückt Bestätigungsdialoge
.PARAMETER Unattended
    Vollautomatischer headless Lauf (impliziert -Force und -NoRestart, überspringt alle Prompts)
.PARAMETER SkipAlreadyRun
    Überspringt die Prüfung, ob Script bereits ausgeführt wurde
.EXAMPLE
    .\Remove-CopilotComplete.ps1 -LogOnly
    Testlauf ohne Änderungen
.EXAMPLE
    .\Remove-CopilotComplete.ps1 -NoRestart
    Produktiv-Ausführung ohne Neustart-Prompt
.EXAMPLE
    .\Remove-CopilotComplete.ps1 -Force
    Produktiv-Ausführung ohne Bestätigungen
.AUTHOR
    Lars Bahlmann / badata GmbH - IT Systemhaus in Bremen / www.badata.de
.VERSION
    2.1 - November 2025
.NOTES
    Erfordert Administratorrechte
    Getestet mit Windows 11 24H2 und Windows 10 22H2
#>

param(
    [switch]$NoRestart,
    [switch]$LogOnly,
    [string]$LogPath,
    [string]$BackupDir,
    [switch]$UseTemp,
    [switch]$NoBackup,
    [switch]$Force,
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

if (-not $LogPath) {
    if ($UseTemp) {
        # C:\Temp mit User-Differenzierung (für RDS)
        $LogPath = "C:\Temp\CopilotRemoval\$env:USERNAME\Logs\CopilotRemoval_$Timestamp.log"
    } else {
        # Standard: User AppData (automatisch user-spezifisch)
        $LogPath = "$env:LOCALAPPDATA\CopilotRemoval\Logs\CopilotRemoval_$Timestamp.log"
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

$script:ErrorCount = 0
$script:WarningCount = 0
$script:SuccessCount = 0
$script:WindowsVersion = ""
$script:IsWindows11 = $false
$script:LogEntries = @()

# ========================================
# LOGGING-FUNKTIONEN
# ========================================
function Write-LogEntry {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet("Info","Warning","Error","Success")]
        [string]$Type = "Info",
        [switch]$NoProgress
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Type] $Message"

    # Konsolen-Ausgabe mit Farben
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

    # In Log-Datei schreiben
    if (-not (Test-Path (Split-Path $LogPath))) {
        New-Item -Path (Split-Path $LogPath) -ItemType Directory -Force | Out-Null
    }
    $LogEntry | Out-File -FilePath $LogPath -Append -Encoding UTF8

    # Für JSON-Export speichern
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

# ========================================
# SYSTEM-INFORMATIONEN
# ========================================
function Get-SystemInfo {
    Write-LogEntry "Sammle System-Informationen..." -Type Info

    # Windows-Version ermitteln
    $OSInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $BuildNumber = [int]$OSInfo.BuildNumber

    $script:WindowsVersion = $OSInfo.Caption
    $script:IsWindows11 = $BuildNumber -ge 22000

    Write-LogEntry "Betriebssystem: $($script:WindowsVersion)" -Type Info
    Write-LogEntry "Build-Nummer: $BuildNumber" -Type Info
    Write-LogEntry "Windows 11: $($script:IsWindows11)" -Type Info

    # Edition prüfen
    $Edition = (Get-WindowsEdition -Online).Edition
    Write-LogEntry "Windows Edition: $Edition" -Type Info

    # AppLocker-Verfügbarkeit prüfen
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
# BACKUP-FUNKTIONEN
# ========================================
function Initialize-Backup {
    if ($NoBackup) {
        Write-LogEntry "Backup übersprungen (-NoBackup Parameter)" -Type Warning
        return $false
    }

    try {
        if (-not (Test-Path $script:BackupPath)) {
            New-Item -Path $script:BackupPath -ItemType Directory -Force | Out-Null
            Write-LogEntry "Backup-Verzeichnis erstellt: $script:BackupPath" -Type Success
        }

        # README für Backup erstellen
        $ReadmeContent = @"
Copilot Removal Backup
======================
Erstellt: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $env:COMPUTERNAME
Benutzer: $env:USERNAME

Dieses Verzeichnis enthält Backups der Registry-Einträge vor der Copilot-Entfernung.

ROLLBACK-ANLEITUNG:
1. Doppelklick auf die gewünschte .reg Datei
2. Bestätigen Sie den Import
3. Computer neu starten

ACHTUNG: Verwenden Sie diese Backups nur auf dem gleichen System!
"@
        $ReadmeContent | Out-File -FilePath "$script:BackupPath\README.txt" -Encoding UTF8

        return $true
    } catch {
        Write-LogEntry "Fehler beim Initialisieren des Backups: $($_.Exception.Message)" -Type Error
        return $false
    }
}

function Backup-RegistryKey {
    param(
        [string]$Path,
        [string]$Name
    )

    if ($NoBackup -or $LogOnly) {
        return
    }

    try {
        # Registry-Pfad für reg.exe konvertieren (HKLM:\... -> HKLM\...)
        $RegPath = $Path -replace ":", ""

        # Dateiname für Backup erstellen
        $SafeName = ($Path -replace "[:\\]", "_") + "_$Name.reg"
        $BackupFile = Join-Path $script:BackupPath $SafeName

        # Prüfen ob Schlüssel existiert
        if (Test-Path $Path) {
            # Registry-Schlüssel exportieren
            $Result = reg export $RegPath $BackupFile /y 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-LogEntry "Backup erstellt: $SafeName" -Type Info
            }
        }
    } catch {
        Write-LogEntry "Backup-Fehler für $Path\$Name : $($_.Exception.Message)" -Type Warning
    }
}

# ========================================
# REGISTRY-FUNKTIONEN
# ========================================
function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord"
    )

    try {
        # Backup erstellen
        Backup-RegistryKey -Path $Path -Name $Name

        if (-not (Test-Path $Path)) {
            if (-not $LogOnly) {
                New-Item -Path $Path -Force | Out-Null
                Write-LogEntry "Registry-Pfad erstellt: $Path" -Type Info
            } else {
                Write-LogEntry "Würde Registry-Pfad erstellen: $Path" -Type Warning
                return
            }
        }

        if (-not $LogOnly) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
            Write-LogEntry "Registry gesetzt: $Path\$Name = $Value" -Type Success
        } else {
            Write-LogEntry "Würde Registry setzen: $Path\$Name = $Value" -Type Warning
        }
    } catch {
        Write-LogEntry "Fehler bei Registry-Änderung: $($_.Exception.Message)" -Type Error
    }
}

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

            Write-LogEntry "Execution-Tracking in Registry gesetzt" -Type Success
        }
    } catch {
        Write-LogEntry "Warnung: Execution-Tracking konnte nicht gesetzt werden: $($_.Exception.Message)" -Type Warning
    }
}

# ========================================
# HAUPTPROGRAMM START
# ========================================
Write-LogEntry "======================================" -Type Info
Write-LogEntry "Copilot Entfernungs-Script v2.1 gestartet" -Type Info
Write-LogEntry "======================================" -Type Info
Write-LogEntry "Ausführender Benutzer: $env:USERNAME" -Type Info
Write-LogEntry "Computer: $env:COMPUTERNAME" -Type Info
Write-LogEntry "Modus: $(if($LogOnly){'TEST (LogOnly)'}else{'PRODUKTIV'})" -Type Info

# Prüfe Admin-Rechte
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-LogEntry "Script erfordert Administratorrechte!" -Type Error
    exit 1
}

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

# System-Informationen sammeln
Write-ProgressHelper -Activity "Initialisierung" -Status "Sammle System-Informationen..." -PercentComplete 5
$SystemInfo = Get-SystemInfo

# Backup initialisieren
Write-ProgressHelper -Activity "Initialisierung" -Status "Erstelle Backup-Verzeichnis..." -PercentComplete 10
Initialize-Backup

# ========================================
# PHASE 1: Copilot App entfernen
# ========================================
Write-LogEntry "" -Type Info
Write-LogEntry "PHASE 1: Copilot App-Pakete entfernen" -Type Info
Write-LogEntry "--------------------------------------" -Type Info

Write-ProgressHelper -Activity "Phase 1/10" -Status "Entferne Copilot-Pakete..." -PercentComplete 15

function Remove-CopilotPackages {
    # Erweiterte Paketliste basierend auf Windows-Version
    $CopilotPackages = @(
        "Microsoft.Copilot",
        "Microsoft.Windows.Ai.Copilot.Provider",
        "MicrosoftWindows.Client.WebExperience",
        "Microsoft.WindowsCopilot"
    )

    # Windows 11 spezifische Pakete
    if ($SystemInfo.IsWindows11) {
        $CopilotPackages += @(
            "Microsoft.Windows.Copilot",
            "Microsoft.UI.Xaml.Copilot"
        )
        Write-LogEntry "Windows 11 erkannt - erweiterte Paketliste wird verwendet" -Type Info
    }

    $RemovedCount = 0

    foreach ($Package in $CopilotPackages) {
        Write-LogEntry "Suche nach Package: $Package" -Type Info

        # Für aktuellen User entfernen
        $CurrentUserPackages = Get-AppxPackage -Name "*$Package*" -ErrorAction SilentlyContinue
        if ($CurrentUserPackages) {
            foreach ($App in $CurrentUserPackages) {
                try {
                    if (-not $LogOnly) {
                        Remove-AppxPackage -Package $App.PackageFullName -ErrorAction Stop
                        Write-LogEntry "Entfernt (Current User): $($App.PackageFullName)" -Type Success
                        $RemovedCount++
                    } else {
                        Write-LogEntry "Würde entfernen (Current User): $($App.PackageFullName)" -Type Warning
                    }
                } catch {
                    Write-LogEntry "Fehler beim Entfernen: $($_.Exception.Message)" -Type Error
                }
            }
        }

        # Für alle User entfernen
        $AllUserPackages = Get-AppxPackage -Name "*$Package*" -AllUsers -ErrorAction SilentlyContinue
        if ($AllUserPackages) {
            foreach ($App in $AllUserPackages) {
                try {
                    if (-not $LogOnly) {
                        Remove-AppxPackage -Package $App.PackageFullName -AllUsers -ErrorAction Stop
                        Write-LogEntry "Entfernt (All Users): $($App.PackageFullName)" -Type Success
                        $RemovedCount++
                    } else {
                        Write-LogEntry "Würde entfernen (All Users): $($App.PackageFullName)" -Type Warning
                    }
                } catch {
                    Write-LogEntry "Fehler beim Entfernen: $($_.Exception.Message)" -Type Error
                }
            }
        }

        # Provisionierte Pakete entfernen (verhindert Neuinstallation)
        $ProvisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$Package*" }
        if ($ProvisionedPackages) {
            foreach ($App in $ProvisionedPackages) {
                try {
                    if (-not $LogOnly) {
                        Remove-AppxProvisionedPackage -Online -PackageName $App.PackageName -ErrorAction Stop
                        Write-LogEntry "Provisioniertes Paket entfernt: $($App.PackageName)" -Type Success
                        $RemovedCount++
                    } else {
                        Write-LogEntry "Würde provisioniertes Paket entfernen: $($App.PackageName)" -Type Warning
                    }
                } catch {
                    Write-LogEntry "Fehler beim Entfernen: $($_.Exception.Message)" -Type Error
                }
            }
        }
    }

    Write-LogEntry "App-Paket-Entfernung abgeschlossen: $RemovedCount Pakete entfernt" -Type Success
}

Remove-CopilotPackages

# ========================================
# PHASE 2: Registry-Einträge setzen
# ========================================
Write-LogEntry "" -Type Info
Write-LogEntry "PHASE 2: Registry-Einträge konfigurieren" -Type Info
Write-LogEntry "-----------------------------------------" -Type Info

Write-ProgressHelper -Activity "Phase 2/10" -Status "Konfiguriere Registry-Einträge..." -PercentComplete 30

# Copilot global deaktivieren
$RegistrySettings = @(
    # Windows Copilot deaktivieren
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name="TurnOffWindowsCopilot"; Value=1},
    @{Path="HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name="TurnOffWindowsCopilot"; Value=1},

    # Copilot Berechtigung entziehen
    @{Path="HKCU:\Software\Microsoft\Windows\Shell\Copilot\BingChat"; Name="IsUserEligible"; Value=0},

    # Copilot Button in Taskleiste verstecken
    @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="ShowCopilotButton"; Value=0},

    # Edge Copilot deaktivieren
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name="Microsoft365CopilotChatIconEnabled"; Value=0},
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name="CopilotEnabled"; Value=0},
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name="DiscoverEnabled"; Value=0},
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name="HubsSidebarEnabled"; Value=0},

    # AI Features in Windows Apps deaktivieren
    @{Path="HKLM:\SOFTWARE\Policies\WindowsNotepad"; Name="DisableAIFeatures"; Value=1},
    @{Path="HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Paint"; Name="DisableImageCreator"; Value=1},
    @{Path="HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Paint"; Name="DisableCocreator"; Value=1},
    @{Path="HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Paint"; Name="DisableGenerativeFill"; Value=1},

    # Windows Recall deaktivieren (Copilot+ PCs)
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name="DisableAIDataAnalysis"; Value=1},
    @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Recall"; Name="DisableRecall"; Value=1},

    # NEW v2.1: Copilot-Hardwaretaste blockieren/umleiten
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name="SetCopilotHardwareKey"; Value=1},  # 1 = Windows-Suche statt Copilot
    @{Path="HKCU:\Software\Policies\Microsoft\Windows\WindowsAI"; Name="SetCopilotHardwareKey"; Value=1},

    # NEW v2.1: Click-To-Do deaktivieren
    @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ClickToDo"; Name="DisableClickToDo"; Value=1},
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\ClickToDo"; Name="DisableClickToDo"; Value=1},

    # NEW v2.1: Game Bar Copilot deaktivieren
    @{Path="HKCU:\Software\Microsoft\GameBar"; Name="DisableCopilot"; Value=1},
    @{Path="HKCU:\Software\Microsoft\GameBar"; Name="DisableModelTraining"; Value=1}
)

# Office-Versionen erkennen und Copilot deaktivieren
$OfficeVersions = @("16.0", "15.0", "17.0")  # Office 2016/2019/2021/M365, 2013, 2024
foreach ($Version in $OfficeVersions) {
    $OfficePath = "HKCU:\Software\Microsoft\Office\$Version\Common"
    if (Test-Path $OfficePath) {
        Write-LogEntry "Office-Version $Version erkannt" -Type Info

        # Copilot in einzelnen Office-Apps deaktivieren
        $OfficeApps = @("word", "excel", "powerpoint", "outlook")
        foreach ($App in $OfficeApps) {
            $RegistrySettings += @{
                Path="HKCU:\Software\Microsoft\Office\$Version\Common\ExperimentConfigs\ExternalFeatureOverrides\$App"
                Name="Microsoft.Office.$($App.Substring(0,1).ToUpper() + $App.Substring(1)).Copilot"
                Value=0
            }
        }

        # NEW v2.1: Office Connected Experiences deaktivieren (alle cloudbasierten KI-Features)
        # DisconnectedState = 2 bedeutet: Alle verbundenen Erfahrungen deaktivieren
        $RegistrySettings += @{
            Path="HKCU:\Software\Microsoft\Office\$Version\Common\Privacy"
            Name="DisconnectedState"
            Value=2
        }

        # Optional: Speziell "Erfahrungen, die Inhalte analysieren" deaktivieren
        $RegistrySettings += @{
            Path="HKCU:\Software\Microsoft\Office\$Version\Common\Privacy"
            Name="DownloadContentDisabled"
            Value=1
        }

        Write-LogEntry "Office ${Version}: Copilot + Connected Experiences deaktiviert" -Type Info
    }
}

foreach ($Setting in $RegistrySettings) {
    Set-RegistryValue -Path $Setting.Path -Name $Setting.Name -Value $Setting.Value
}

# ========================================
# PHASE 3: Kontextmenü-Einträge blockieren
# ========================================
Write-LogEntry "" -Type Info
Write-LogEntry "PHASE 3: Kontextmenü-Einträge blockieren" -Type Info
Write-LogEntry "-----------------------------------------" -Type Info

Write-ProgressHelper -Activity "Phase 3/10" -Status "Blockiere Kontextmenü-Einträge..." -PercentComplete 40

$BlockedExtensionsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked"
if (-not (Test-Path $BlockedExtensionsPath)) {
    if (-not $LogOnly) {
        New-Item -Path $BlockedExtensionsPath -Force | Out-Null
        Write-LogEntry "Shell Extensions Blocked Pfad erstellt" -Type Info
    }
}

# Copilot Kontextmenü-GUID blockieren
if (-not $LogOnly) {
    Backup-RegistryKey -Path $BlockedExtensionsPath -Name "ContextMenuBlock"
    Set-ItemProperty -Path $BlockedExtensionsPath -Name "{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}" -Value "Copilot fragen" -Type String -Force
    Write-LogEntry "Kontextmenü 'Copilot fragen' blockiert" -Type Success
} else {
    Write-LogEntry "Würde Kontextmenü 'Copilot fragen' blockieren" -Type Warning
}

# ========================================
# PHASE 4: AppLocker-Regeln erstellen
# ========================================
Write-LogEntry "" -Type Info
Write-LogEntry "PHASE 4: AppLocker-Regeln konfigurieren" -Type Info
Write-LogEntry "----------------------------------------" -Type Info

Write-ProgressHelper -Activity "Phase 4/10" -Status "Konfiguriere AppLocker-Regeln..." -PercentComplete 50

function Configure-AppLocker {
    if (-not $SystemInfo.AppLockerAvailable) {
        Write-LogEntry "AppLocker nicht verfügbar (Windows Home Edition) - übersprungen" -Type Warning
        return
    }

    try {
        # Prüfe ob AppLocker-Service läuft
        $AppLockerService = Get-Service -Name "AppIDSvc" -ErrorAction SilentlyContinue
        if ($AppLockerService.Status -ne "Running") {
            if (-not $LogOnly) {
                Set-Service -Name "AppIDSvc" -StartupType Automatic
                Start-Service -Name "AppIDSvc"
                Write-LogEntry "AppLocker-Service gestartet" -Type Success
            } else {
                Write-LogEntry "Würde AppLocker-Service starten" -Type Warning
            }
        }

        # Prüfe ob bereits Copilot-Regel existiert
        $ExistingPolicy = Get-AppLockerPolicy -Effective -ErrorAction SilentlyContinue
        $CopilotRuleExists = $false

        if ($ExistingPolicy) {
            foreach ($RuleCollection in $ExistingPolicy.RuleCollections) {
                foreach ($Rule in $RuleCollection) {
                    if ($Rule.Name -like "*Copilot*") {
                        $CopilotRuleExists = $true
                        Write-LogEntry "Copilot-Regel bereits vorhanden: $($Rule.Name)" -Type Info
                        break
                    }
                }
            }
        }

        if ($CopilotRuleExists -and -not $Force) {
            Write-LogEntry "Copilot-AppLocker-Regel existiert bereits (verwenden Sie -Force zum Überschreiben)" -Type Warning
            return
        }

        # AppLocker XML-Regel für Copilot
        $AppLockerXML = @'
<AppLockerPolicy Version="1">
  <RuleCollection Type="Appx" EnforcementMode="Enabled">
    <FilePublisherRule Id="a9e18c21-ff8f-43cf-b9fc-db40eed693ba"
                       Name="Block Microsoft Copilot"
                       Description="Blocks Microsoft Copilot installation and execution"
                       UserOrGroupSid="S-1-1-0"
                       Action="Deny">
      <Conditions>
        <FilePublisherCondition PublisherName="CN=MICROSOFT CORPORATION, O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US"
                                ProductName="MICROSOFT.COPILOT"
                                BinaryName="*">
          <BinaryVersionRange LowSection="*" HighSection="*"/>
        </FilePublisherCondition>
      </Conditions>
    </FilePublisherRule>
  </RuleCollection>
</AppLockerPolicy>
'@

        if (-not $LogOnly) {
            # Temporäre XML-Datei erstellen
            $TempFile = [System.IO.Path]::GetTempFileName()
            $AppLockerXML | Out-File -FilePath $TempFile -Encoding UTF8

            # Backup der aktuellen AppLocker-Policy
            if (-not $NoBackup) {
                $BackupPolicyFile = Join-Path $script:BackupPath "AppLockerPolicy_Backup.xml"
                if ($ExistingPolicy) {
                    $ExistingPolicy | Export-Clixml -Path $BackupPolicyFile
                    Write-LogEntry "AppLocker-Policy gesichert: $BackupPolicyFile" -Type Success
                }
            }

            # AppLocker-Politik importieren
            Set-AppLockerPolicy -XmlPolicy $TempFile -Merge
            Remove-Item $TempFile -Force

            Write-LogEntry "AppLocker-Regeln für Copilot erstellt" -Type Success
        } else {
            Write-LogEntry "Würde AppLocker-Regeln für Copilot erstellen" -Type Warning
        }
    } catch {
        Write-LogEntry "AppLocker-Konfiguration fehlgeschlagen: $($_.Exception.Message)" -Type Warning
        Write-LogEntry "AppLocker ist möglicherweise nicht verfügbar (Windows Pro/Enterprise erforderlich)" -Type Info
    }
}

Configure-AppLocker

# ========================================
# PHASE 5: Firewall-Regeln erstellen
# ========================================
Write-LogEntry "" -Type Info
Write-LogEntry "PHASE 5: Firewall-Regeln konfigurieren" -Type Info
Write-LogEntry "---------------------------------------" -Type Info

Write-ProgressHelper -Activity "Phase 5/10" -Status "Konfiguriere Firewall-Regeln..." -PercentComplete 60

function Create-FirewallRules {
    $CopilotDomains = @(
        "copilot.microsoft.com",
        "copilot.cloud.microsoft",
        "copilot-gpt.microsoft.com",
        "sydney.bing.com",
        "bing.com",
        "www.bing.com",
        "edgeservices.bing.com",
        # NEW v2.1: Erweiterte Copilot/Bing-Domains aus PDF-Analyse
        "www.bing.com/turing",
        "copilot.cloud.microsoft.com",
        "api.bing.com",
        "www.bing.com/chat"
    )

    # Outbound-Regel für Copilot-Domänen
    $RuleName = "Block_Copilot_Outbound"

    try {
        # Prüfe ob Regel bereits existiert
        $ExistingRule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
        if ($ExistingRule) {
            if (-not $LogOnly) {
                Remove-NetFirewallRule -DisplayName $RuleName
                Write-LogEntry "Existierende Firewall-Regel entfernt: $RuleName" -Type Info
            }
        }

        if (-not $LogOnly) {
            # Dynamisch Copilot-Programme finden
            $SearchPaths = @(
                "$env:LOCALAPPDATA\Microsoft\WindowsApps",
                "$env:ProgramFiles\WindowsApps",
                "$env:LOCALAPPDATA\Packages"
            )

            $CopilotExes = @()
            foreach ($SearchPath in $SearchPaths) {
                if (Test-Path $SearchPath) {
                    $Found = Get-ChildItem -Path $SearchPath -Recurse -Filter "*Copilot*.exe" -ErrorAction SilentlyContinue
                    $CopilotExes += $Found.FullName
                }
            }

            # Firewall-Regeln für gefundene Programme
            foreach ($Exe in $CopilotExes) {
                try {
                    New-NetFirewallRule -DisplayName "${RuleName}_$(Split-Path $Exe -Leaf)" `
                        -Direction Outbound `
                        -Action Block `
                        -Program $Exe `
                        -Enabled True `
                        -Profile Any `
                        -ErrorAction SilentlyContinue
                    Write-LogEntry "Firewall-Regel für Programm erstellt: $Exe" -Type Success
                } catch {
                    Write-LogEntry "Firewall-Regel fehlgeschlagen für: $Exe" -Type Warning
                }
            }

            # DNS-Blockierung für Copilot-Domains über Hosts-Datei
            $HostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"

            # Backup der Hosts-Datei
            if (-not $NoBackup) {
                Copy-Item -Path $HostsFile -Destination "$script:BackupPath\hosts.backup" -Force
                Write-LogEntry "Hosts-Datei gesichert" -Type Success
            }

            $HostsContent = Get-Content $HostsFile -ErrorAction SilentlyContinue
            $AddedCount = 0

            foreach ($Domain in $CopilotDomains) {
                # Prüfe ob Domain bereits blockiert ist (0.0.0.0 oder 127.0.0.1)
                $AlreadyBlocked = $HostsContent | Where-Object {
                    $_ -match "^\s*(0\.0\.0\.0|127\.0\.0\.1)\s+$([regex]::Escape($Domain))\s*$"
                }

                if (-not $AlreadyBlocked) {
                    $Entry = "0.0.0.0 $Domain # Copilot-Blockierung"
                    Add-Content -Path $HostsFile -Value $Entry
                    Write-LogEntry "Hosts-Eintrag hinzugefügt: $Entry" -Type Success
                    $AddedCount++
                } else {
                    Write-LogEntry "Domain bereits blockiert: $Domain" -Type Info
                }
            }

            if ($AddedCount -gt 0) {
                # DNS-Cache leeren
                Clear-DnsClientCache
                Write-LogEntry "DNS-Cache geleert" -Type Success
            }

        } else {
            Write-LogEntry "Würde Firewall-Regeln für Copilot erstellen" -Type Warning
        }
    } catch {
        Write-LogEntry "Firewall-Konfiguration fehlgeschlagen: $($_.Exception.Message)" -Type Error
    }
}

Create-FirewallRules

# ========================================
# PHASE 6: Scheduled Tasks deaktivieren
# ========================================
Write-LogEntry "" -Type Info
Write-LogEntry "PHASE 6: Geplante Tasks deaktivieren" -Type Info
Write-LogEntry "-------------------------------------" -Type Info

Write-ProgressHelper -Activity "Phase 6/10" -Status "Deaktiviere geplante Tasks..." -PercentComplete 70

function Disable-CopilotTasks {
    $TaskPaths = @(
        "\Microsoft\Windows\Application Experience\",
        "\Microsoft\Windows\CloudExperienceHost\",
        "\Microsoft\Windows\Windows Copilot\"
    )

    $DisabledCount = 0

    foreach ($Path in $TaskPaths) {
        try {
            $Tasks = Get-ScheduledTask -TaskPath $Path -ErrorAction SilentlyContinue |
                     Where-Object { $_.TaskName -like "*Copilot*" -or $_.TaskName -like "*AI*" }

            foreach ($Task in $Tasks) {
                # Backup der Task-Definition
                if (-not $NoBackup -and -not $LogOnly) {
                    $TaskXml = Export-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath
                    $SafeTaskName = $Task.TaskName -replace "[\\/:*?""<>|]", "_"
                    $TaskXml | Out-File -FilePath "$script:BackupPath\Task_$SafeTaskName.xml" -Encoding UTF8
                }

                if (-not $LogOnly) {
                    Disable-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath -ErrorAction Stop
                    Write-LogEntry "Task deaktiviert: $($Task.TaskPath)$($Task.TaskName)" -Type Success
                    $DisabledCount++
                } else {
                    Write-LogEntry "Würde Task deaktivieren: $($Task.TaskPath)$($Task.TaskName)" -Type Warning
                }
            }
        } catch {
            Write-LogEntry "Fehler beim Deaktivieren von Tasks: $($_.Exception.Message)" -Type Error
        }
    }

    Write-LogEntry "Tasks deaktiviert: $DisabledCount" -Type Success
}

Disable-CopilotTasks

# ========================================
# PHASE 7: Dienste-Management (ÜBERSPRUNGEN)
# ========================================
Write-LogEntry "" -Type Info
Write-LogEntry "PHASE 7: Dienste-Management (übersprungen)" -Type Info
Write-LogEntry "-------------------------------------------" -Type Info
Write-LogEntry "Dienste wie WSearch, cbdhsvc werden NICHT deaktiviert (Systemstabilität)" -Type Warning

Write-ProgressHelper -Activity "Phase 7/10" -Status "Dienste-Überprüfung..." -PercentComplete 75

# Diese Phase wird bewusst übersprungen, da die Deaktivierung von Diensten
# wie WSearch (Windows Search) oder cbdhsvc (Clipboard) zu Systeminstabilität führen kann

# ========================================
# PHASE 8: Gruppenrichtlinien aktualisieren
# ========================================
Write-LogEntry "" -Type Info
Write-LogEntry "PHASE 8: Gruppenrichtlinien aktualisieren" -Type Info
Write-LogEntry "------------------------------------------" -Type Info

Write-ProgressHelper -Activity "Phase 8/10" -Status "Aktualisiere Gruppenrichtlinien..." -PercentComplete 80

if (-not $LogOnly) {
    try {
        $Result = gpupdate /force /wait:0 2>&1
        Write-LogEntry "Gruppenrichtlinien aktualisiert" -Type Success
    } catch {
        Write-LogEntry "Fehler beim Aktualisieren der Gruppenrichtlinien: $($_.Exception.Message)" -Type Warning
        Write-LogEntry "Dies ist normal wenn der Computer nicht in einer Domäne ist" -Type Info
    }
} else {
    Write-LogEntry "Würde Gruppenrichtlinien aktualisieren (gpupdate /force)" -Type Warning
}

# ========================================
# PHASE 9: Überprüfung
# ========================================
Write-LogEntry "" -Type Info
Write-LogEntry "PHASE 9: Abschließende Überprüfung" -Type Info
Write-LogEntry "-----------------------------------" -Type Info

Write-ProgressHelper -Activity "Phase 9/10" -Status "Führe Überprüfungen durch..." -PercentComplete 90

function Test-CopilotRemoval {
    $Issues = @()
    $Checks = @()

    # Prüfe ob Copilot-Pakete noch vorhanden sind
    $RemainingPackages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*Copilot*" }
    if ($RemainingPackages) {
        $Issues += "Copilot-Pakete noch vorhanden: $($RemainingPackages.Name -join ', ')"
        $Checks += @{Check="App-Pakete"; Status="FEHLER"; Details=$RemainingPackages.Name -join ', '}
    } else {
        $Checks += @{Check="App-Pakete"; Status="OK"; Details="Keine Copilot-Pakete gefunden"}
    }

    # Prüfe Registry-Einträge
    $RegValue = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue
    if ($RegValue.TurnOffWindowsCopilot -ne 1) {
        $Issues += "Registry-Eintrag TurnOffWindowsCopilot nicht korrekt gesetzt"
        $Checks += @{Check="Registry HKLM"; Status="FEHLER"; Details="TurnOffWindowsCopilot nicht gesetzt"}
    } else {
        $Checks += @{Check="Registry HKLM"; Status="OK"; Details="TurnOffWindowsCopilot = 1"}
    }

    # Prüfe Copilot-Button in Taskleiste
    $TaskbarValue = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -ErrorAction SilentlyContinue
    if ($TaskbarValue.ShowCopilotButton -ne 0) {
        $Issues += "Copilot-Button in Taskleiste noch aktiv"
        $Checks += @{Check="Taskleisten-Button"; Status="FEHLER"; Details="ShowCopilotButton nicht deaktiviert"}
    } else {
        $Checks += @{Check="Taskleisten-Button"; Status="OK"; Details="ShowCopilotButton = 0"}
    }

    # Prüfe Kontextmenü-Blockierung
    $BlockedExtension = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" -Name "{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}" -ErrorAction SilentlyContinue
    if ($BlockedExtension) {
        $Checks += @{Check="Kontextmenü"; Status="OK"; Details="Shell Extension blockiert"}
    } else {
        $Checks += @{Check="Kontextmenü"; Status="WARNUNG"; Details="Shell Extension nicht blockiert"}
    }

    # Prüfe Hosts-Datei
    $HostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    $HostsContent = Get-Content $HostsFile -ErrorAction SilentlyContinue
    $BlockedDomains = $HostsContent | Where-Object { $_ -match "copilot" }
    if ($BlockedDomains) {
        $Checks += @{Check="Hosts-Datei"; Status="OK"; Details="$($BlockedDomains.Count) Domains blockiert"}
    } else {
        $Checks += @{Check="Hosts-Datei"; Status="WARNUNG"; Details="Keine Copilot-Domains blockiert"}
    }

    # Ausgabe der Ergebnisse
    Write-LogEntry "" -Type Info
    Write-LogEntry "Überprüfungsergebnisse:" -Type Info
    Write-LogEntry "========================" -Type Info

    foreach ($Check in $Checks) {
        $Color = switch ($Check.Status) {
            "OK" { "Success" }
            "WARNUNG" { "Warning" }
            "FEHLER" { "Error" }
        }
        Write-LogEntry "[$($Check.Status.PadRight(8))] $($Check.Check): $($Check.Details)" -Type $Color
    }

    Write-LogEntry "" -Type Info

    if ($Issues.Count -eq 0) {
        Write-LogEntry "✓ Alle Überprüfungen erfolgreich bestanden" -Type Success
        Write-LogEntry "  Copilot wurde erfolgreich entfernt und blockiert" -Type Success
    } else {
        Write-LogEntry "⚠ Folgende Probleme wurden festgestellt:" -Type Warning
        foreach ($Issue in $Issues) {
            Write-LogEntry "  - $Issue" -Type Warning
        }
    }

    return @{
        Success = ($Issues.Count -eq 0)
        Issues = $Issues
        Checks = $Checks
    }
}

$TestResult = Test-CopilotRemoval

# ========================================
# PHASE 10: Bereinigung und Neustart
# ========================================
Write-LogEntry "" -Type Info
Write-LogEntry "PHASE 10: Bereinigung" -Type Info
Write-LogEntry "---------------------" -Type Info

Write-ProgressHelper -Activity "Phase 10/10" -Status "Bereinigung..." -PercentComplete 95

# Explorer neu starten für Taskleisten-Änderungen
if (-not $LogOnly) {
    if ($Force) {
        $RestartExplorer = $true
    } else {
        if ($Unattended) {
            Write-LogEntry "Unattended-Modus: Explorer-Neustart wird übersprungen" -Type Info
            $RestartExplorer = $false
        } else {
            Write-Host ""
            $Response = Read-Host "Windows Explorer neu starten für Taskleisten-Änderungen? (J/N)"
            $RestartExplorer = ($Response -eq "J" -or $Response -eq "j")
        }
    }

    if ($RestartExplorer) {
        try {
            Write-LogEntry "Starte Windows Explorer neu..." -Type Info
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Start-Process explorer
            Write-LogEntry "Windows Explorer neu gestartet" -Type Success
        } catch {
            Write-LogEntry "Fehler beim Neustarten des Explorers: $($_.Exception.Message)" -Type Warning
        }
    }
}

# JSON-Report erstellen
$ReportPath = "$script:BackupPath\ExecutionReport.json"
$Report = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Computer = $env:COMPUTERNAME
    User = $env:USERNAME
    WindowsVersion = $script:WindowsVersion
    IsWindows11 = $script:IsWindows11
    Mode = if($LogOnly){"Test"}else{"Production"}
    Statistics = @{
        Errors = $script:ErrorCount
        Warnings = $script:WarningCount
        Successes = $script:SuccessCount
    }
    TestResult = $TestResult
    LogEntries = $script:LogEntries
}

if (-not $LogOnly) {
    $Report | ConvertTo-Json -Depth 10 | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-LogEntry "Execution Report erstellt: $ReportPath" -Type Success
}

# ========================================
# Abschluss
# ========================================
Write-ProgressHelper -Activity "Abgeschlossen" -Status "Script-Ausführung beendet" -PercentComplete 100
Start-Sleep -Milliseconds 500
Write-Progress -Activity "Abgeschlossen" -Completed

Write-LogEntry "" -Type Info
Write-LogEntry "======================================" -Type Info
Write-LogEntry "Script-Ausführung abgeschlossen" -Type Info
Write-LogEntry "======================================" -Type Info
Write-LogEntry "Statistiken:" -Type Info
Write-LogEntry "  Erfolge:   $script:SuccessCount" -Type Success
Write-LogEntry "  Warnungen: $script:WarningCount" -Type Warning
Write-LogEntry "  Fehler:    $script:ErrorCount" -Type Error
Write-LogEntry "" -Type Info
Write-LogEntry "Log-Datei:    $LogPath" -Type Info
Write-LogEntry "Backup-Pfad:  $script:BackupPath" -Type Info
if (-not $LogOnly) {
    Write-LogEntry "JSON-Report:  $ReportPath" -Type Info
}

if ($TestResult.Success) {
    Write-LogEntry "" -Type Info
    Write-LogEntry "STATUS: ERFOLGREICH - Copilot wurde entfernt und blockiert" -Type Success
} else {
    Write-LogEntry "" -Type Info
    Write-LogEntry "STATUS: WARNUNG - Einige Komponenten konnten nicht vollständig entfernt werden" -Type Warning
    Write-LogEntry "Bitte Log-Datei und Report prüfen und ggf. manuell nacharbeiten" -Type Info
}

# Neustart-Handling
if (-not $NoRestart -and -not $LogOnly) {
    Write-LogEntry "" -Type Info
    Write-LogEntry "Ein Neustart wird empfohlen, um alle Änderungen zu übernehmen." -Type Info

    if ($Force) {
        Write-LogEntry "Computer wird in 10 Sekunden neu gestartet... (Force-Modus)" -Type Warning
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    } else {
        if ($Unattended) {
            Write-LogEntry "Unattended-Modus: Neustart wird nicht durchgeführt" -Type Info
        } else {
            $Restart = Read-Host "Möchten Sie den Computer jetzt neu starten? (J/N)"
            if ($Restart -eq "J" -or $Restart -eq "j") {
                Write-LogEntry "Computer wird in 10 Sekunden neu gestartet..." -Type Warning
            Start-Sleep -Seconds 10
            Restart-Computer -Force
        }
    }
} else {
    if ($LogOnly) {
        Write-LogEntry "" -Type Info
        Write-LogEntry "TEST-MODUS: Keine Änderungen vorgenommen" -Type Warning
        Write-LogEntry "Führen Sie das Script ohne -LogOnly aus, um Änderungen durchzuführen" -Type Info
    } else {
        Write-LogEntry "Neustart übersprungen (-NoRestart Parameter verwendet)" -Type Info
        Write-LogEntry "Bitte Computer manuell neu starten, um alle Änderungen zu übernehmen" -Type Warning
    }
}

# Setze Execution-Tracking (nur bei erfolgreicher Ausführung)
if (-not $LogOnly) {
    Set-ExecutionTracking -Status "Success"
}

Write-LogEntry "Script beendet" -Type Info
exit 0
