<#
.SYNOPSIS
    Ueberprueft ob Microsoft Copilot auf dem System vorhanden ist
.DESCRIPTION
    Dieses Script fuehrt umfassende Ueberpruefungen durch, ob Microsoft Copilot
    auf dem System installiert ist oder Blockierungen aktiv sind.

    Kann als Scheduled Task fuer regelmaessige Ueberwachung verwendet werden.
.PARAMETER EmailAlert
    E-Mail-Adresse fuer Benachrichtigungen (optional)
.PARAMETER SMTPServer
    SMTP-Server fuer E-Mail-Versand (optional)
.PARAMETER CreateScheduledTask
    Erstellt einen Scheduled Task fuer monatliche Ueberpruefung
.PARAMETER LogPath
    Pfad zur Log-Datei (Standard: $env:LOCALAPPDATA\CopilotRemoval\Logs\...)
.PARAMETER UseTemp
    Verwendet C:\Temp statt AppData (mit User-Differenzierung fuer RDS)
.EXAMPLE
    .\Test-CopilotPresence.ps1
    Fuehrt einfache Ueberpruefung durch
.EXAMPLE
    .\Test-CopilotPresence.ps1 -EmailAlert admin@firma.de -SMTPServer mail.firma.de
    Fuehrt Ueberpruefung durch und sendet E-Mail bei Fund
.EXAMPLE
    .\Test-CopilotPresence.ps1 -CreateScheduledTask
    Erstellt monatlichen Scheduled Task
.AUTHOR
    Lars Bahlmann / badata GmbH - IT Systemhaus in Bremen / www.badata.de
.VERSION
    1.1 - November 2025 (Microsoft 365 Copilot Checks)
#>

param(
    [string]$EmailAlert,
    [string]$SMTPServer,
    [switch]$CreateScheduledTask,
    [string]$LogPath,
    [switch]$UseTemp,
    [switch]$Force
)

# Automatische Pfad-Ermittlung (RDS-sicher, ohne Systemordner-Aenderungen)
if (-not $LogPath) {
    $DateStamp = Get-Date -Format 'yyyyMMdd'
    if ($UseTemp) {
        # C:\Temp mit User-Differenzierung (fuer RDS) - WICHTIG: Mit USERNAME!
        $LogPath = "C:\Temp\CopilotRemoval\$env:USERNAME\Logs\CopilotMonitoring_$DateStamp.log"
    } else {
        # Standard: User AppData (automatisch user-spezifisch)
        $LogPath = "$env:LOCALAPPDATA\CopilotRemoval\Logs\CopilotMonitoring_$DateStamp.log"
    }
}

# ========================================
# FUNKTIONEN
# ========================================
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info","Warning","Error","Success")]
        [string]$Type = "Info"
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Type] $Message"

    switch ($Type) {
        "Error"   { Write-Host $LogEntry -ForegroundColor Red }
        "Warning" { Write-Host $LogEntry -ForegroundColor Yellow }
        "Success" { Write-Host $LogEntry -ForegroundColor Green }
        default   { Write-Host $LogEntry }
    }

    if (-not (Test-Path (Split-Path $LogPath))) {
        New-Item -Path (Split-Path $LogPath) -ItemType Directory -Force | Out-Null
    }
    $LogEntry | Out-File -FilePath $LogPath -Append -Encoding UTF8
}

function Test-AppPackages {
    Write-Log "Pruefe App-Pakete..." -Type Info

    $CopilotPackages = @(
        "Microsoft.Copilot",
        "Microsoft.Windows.Ai.Copilot.Provider",
        "MicrosoftWindows.Client.WebExperience",
        "Microsoft.WindowsCopilot",
        "Microsoft.Windows.Copilot"
    )

    $Found = @()

    foreach ($Package in $CopilotPackages) {
        $Installed = Get-AppxPackage -AllUsers -Name "*$Package*" -ErrorAction SilentlyContinue
        if ($Installed) {
            $Found += $Installed
            Write-Log "GEFUNDEN: $($Installed.Name) - $($Installed.PackageFullName)" -Type Warning
        }
    }

    # Provisionierte Pakete pruefen
    $Provisioned = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*Copilot*" }
    if ($Provisioned) {
        $Found += $Provisioned
        Write-Log "GEFUNDEN: Provisioniertes Paket - $($Provisioned.DisplayName)" -Type Warning
    }

    if ($Found.Count -eq 0) {
        Write-Log "OK: Keine Copilot App-Pakete gefunden" -Type Success
        return @{Status="OK"; Found=$null}
    } else {
        return @{Status="GEFUNDEN"; Found=$Found}
    }
}

function Test-RegistrySettings {
    Write-Log "Pruefe Registry-Einstellungen..." -Type Info

    $Checks = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name="TurnOffWindowsCopilot"; Expected=1},
        @{Path="HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name="TurnOffWindowsCopilot"; Expected=1},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="ShowCopilotButton"; Expected=0},

        # NEW v2.1: Erweiterte Pruefungen
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name="SetCopilotHardwareKey"; Expected=1},  # Hardwaretaste
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Recall"; Name="DisableRecall"; Expected=1},  # Recall
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ClickToDo"; Name="DisableClickToDo"; Expected=1},  # Click-To-Do
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="DisableCopilot"; Expected=1}  # Game Bar Copilot
    )

    $Issues = @()

    foreach ($Check in $Checks) {
        try {
            $Value = Get-ItemProperty -Path $Check.Path -Name $Check.Name -ErrorAction SilentlyContinue
            if ($null -eq $Value -or $Value.($Check.Name) -ne $Check.Expected) {
                $Issues += "$($Check.Path)\$($Check.Name) ist nicht korrekt gesetzt"
                Write-Log "FEHLER: $($Check.Path)\$($Check.Name) = $($Value.($Check.Name)) (erwartet: $($Check.Expected))" -Type Warning
            } else {
                Write-Log "OK: $($Check.Path)\$($Check.Name) = $($Check.Expected)" -Type Success
            }
        } catch {
            $Issues += "$($Check.Path)\$($Check.Name) existiert nicht"
            Write-Log "FEHLER: $($Check.Path)\$($Check.Name) existiert nicht" -Type Warning
        }
    }

    if ($Issues.Count -eq 0) {
        return @{Status="OK"; Issues=$null}
    } else {
        return @{Status="FEHLER"; Issues=$Issues}
    }
}

function Test-ContextMenu {
    Write-Log "Pruefe Kontextmenue-Blockierung..." -Type Info

    $BlockedPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked"
    $CopilotGUID = "{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}"

    try {
        $Blocked = Get-ItemProperty -Path $BlockedPath -Name $CopilotGUID -ErrorAction SilentlyContinue
        if ($Blocked) {
            Write-Log "OK: Kontextmenue-Extension blockiert" -Type Success
            return @{Status="OK"; Details="Blockiert"}
        } else {
            Write-Log "WARNUNG: Kontextmenue-Extension nicht blockiert" -Type Warning
            return @{Status="FEHLER"; Details="Nicht blockiert"}
        }
    } catch {
        Write-Log "FEHLER: Kontextmenue-Blockierung nicht konfiguriert" -Type Warning
        return @{Status="FEHLER"; Details="Nicht konfiguriert"}
    }
}

function Test-HostsFile {
    Write-Log "Pruefe Hosts-Datei..." -Type Info

    $HostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    $ExpectedDomains = @(
        "copilot.microsoft.com",
        "sydney.bing.com"
    )

    $HostsContent = Get-Content $HostsFile -ErrorAction SilentlyContinue
    $BlockedCount = 0

    foreach ($Domain in $ExpectedDomains) {
        $Blocked = $HostsContent | Where-Object { $_ -match "^\s*(0\.0\.0\.0|127\.0\.0\.1)\s+$([regex]::Escape($Domain))" }
        if ($Blocked) {
            $BlockedCount++
            Write-Log "OK: Domain blockiert - $Domain" -Type Success
        } else {
            Write-Log "WARNUNG: Domain nicht blockiert - $Domain" -Type Warning
        }
    }

    return @{
        Status=if($BlockedCount -eq $ExpectedDomains.Count){"OK"}else{"TEILWEISE"}
        BlockedCount=$BlockedCount
        TotalCount=$ExpectedDomains.Count
    }
}

function Test-FirewallRules {
    Write-Log "Pruefe Firewall-Regeln..." -Type Info

    $CopilotRules = Get-NetFirewallRule -DisplayName "*Copilot*" -ErrorAction SilentlyContinue

    if ($CopilotRules) {
        $BlockRules = $CopilotRules | Where-Object { $_.Action -eq "Block" }
        Write-Log "OK: $($BlockRules.Count) Copilot-Blockierungsregeln gefunden" -Type Success
        return @{Status="OK"; RuleCount=$BlockRules.Count}
    } else {
        Write-Log "WARNUNG: Keine Copilot-Firewall-Regeln gefunden" -Type Warning
        return @{Status="FEHLER"; RuleCount=0}
    }
}

function Test-ScheduledTasks {
    Write-Log "Pruefe Scheduled Tasks..." -Type Info

    $TaskPaths = @(
        "\Microsoft\Windows\Application Experience\",
        "\Microsoft\Windows\CloudExperienceHost\",
        "\Microsoft\Windows\Windows Copilot\"
    )

    $ActiveTasks = @()

    foreach ($Path in $TaskPaths) {
        $Tasks = Get-ScheduledTask -TaskPath $Path -ErrorAction SilentlyContinue |
                 Where-Object { ($_.TaskName -like "*Copilot*" -or $_.TaskName -like "*AI*") -and $_.State -eq "Ready" }

        if ($Tasks) {
            $ActiveTasks += $Tasks
            foreach ($Task in $Tasks) {
                Write-Log "WARNUNG: Aktiver Task gefunden - $($Task.TaskPath)$($Task.TaskName)" -Type Warning
            }
        }
    }

    if ($ActiveTasks.Count -eq 0) {
        Write-Log "OK: Keine aktiven Copilot-Tasks gefunden" -Type Success
        return @{Status="OK"; ActiveCount=0}
    } else {
        return @{Status="FEHLER"; ActiveCount=$ActiveTasks.Count}
    }
}

function Test-OfficeConnectedExperiences {
    Write-Log "Pruefe Office Connected Experiences..." -Type Info

    $OfficeVersions = @("16.0", "15.0", "17.0")
    $Issues = @()
    $CheckedVersions = 0

    foreach ($Version in $OfficeVersions) {
        $OfficePath = "HKCU:\Software\Microsoft\Office\$Version\Common\Privacy"
        if (Test-Path $OfficePath) {
            $CheckedVersions++

            # Pruefe DisconnectedState (sollte 2 sein)
            try {
                $DisconnectedState = Get-ItemProperty -Path $OfficePath -Name "DisconnectedState" -ErrorAction SilentlyContinue
                if ($null -eq $DisconnectedState -or $DisconnectedState.DisconnectedState -ne 2) {
                    $Issues += "Office ${Version}: DisconnectedState nicht korrekt gesetzt"
                    Write-Log "WARNUNG: Office ${Version} DisconnectedState = $($DisconnectedState.DisconnectedState) (erwartet: 2)" -Type Warning
                } else {
                    Write-Log "OK: Office ${Version} DisconnectedState = 2" -Type Success
                }
            } catch {
                $Issues += "Office ${Version}: DisconnectedState fehlt"
                Write-Log "WARNUNG: Office ${Version} DisconnectedState fehlt" -Type Warning
            }
        }
    }

    if ($CheckedVersions -eq 0) {
        Write-Log "INFO: Keine Office-Installation gefunden" -Type Info
        return @{Status="NICHT_ANWENDBAR"; Issues=$null}
    }

    if ($Issues.Count -eq 0) {
        Write-Log "OK: Office Connected Experiences korrekt deaktiviert" -Type Success
        return @{Status="OK"; Issues=$null}
    } else {
        return @{Status="FEHLER"; Issues=$Issues}
    }
}

function Test-Microsoft365Copilot {
    Write-Log "Pruefe Microsoft 365 Copilot..." -Type Info

    $Checks = @(
        # Main Toggle
        @{Path="HKCU:\Software\Policies\Microsoft\office\16.0\common\copilot"; Name="TurnOffCopilot"; Expected=1},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\copilot"; Name="TurnOffCopilot"; Expected=1},

        # Per-Application
        @{Path="HKCU:\Software\Policies\Microsoft\office\16.0\word\options\copilot"; Name="DisableCopilot"; Expected=1},
        @{Path="HKCU:\Software\Policies\Microsoft\office\16.0\excel\options\copilot"; Name="DisableCopilot"; Expected=1},
        @{Path="HKCU:\Software\Policies\Microsoft\office\16.0\powerpoint\options\copilot"; Name="DisableCopilot"; Expected=1},
        @{Path="HKCU:\Software\Policies\Microsoft\office\16.0\outlook\options\copilot"; Name="DisableCopilot"; Expected=1},

        # Additional Controls
        @{Path="HKCU:\Software\Policies\Microsoft\office\16.0\common"; Name="AllowCopilot"; Expected=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common"; Name="AllowCopilot"; Expected=0}
    )

    $Issues = @()
    $CheckedCount = 0
    $OfficeInstalled = Test-Path "HKCU:\Software\Microsoft\Office\16.0"

    if (-not $OfficeInstalled) {
        Write-Log "INFO: Office 16.0 (365/2019/2021) nicht installiert" -Type Info
        return @{Status="NICHT_ANWENDBAR"; Issues=$null}
    }

    foreach ($Check in $Checks) {
        try {
            $Value = Get-ItemProperty -Path $Check.Path -Name $Check.Name -ErrorAction SilentlyContinue
            if ($null -eq $Value -or $Value.($Check.Name) -ne $Check.Expected) {
                $Issues += "$($Check.Path)\$($Check.Name) ist nicht korrekt gesetzt"
                Write-Log "WARNUNG: $($Check.Path)\$($Check.Name) = $($Value.($Check.Name)) (erwartet: $($Check.Expected))" -Type Warning
            } else {
                Write-Log "OK: $($Check.Path)\$($Check.Name) = $($Check.Expected)" -Type Success
                $CheckedCount++
            }
        } catch {
            $Issues += "$($Check.Path)\$($Check.Name) existiert nicht"
            Write-Log "WARNUNG: $($Check.Path)\$($Check.Name) existiert nicht" -Type Warning
        }
    }

    if ($Issues.Count -eq 0) {
        Write-Log "OK: Microsoft 365 Copilot vollstaendig blockiert ($CheckedCount Einstellungen)" -Type Success
        return @{Status="OK"; Issues=$null}
    } else {
        return @{Status="FEHLER"; Issues=$Issues}
    }
}

function Send-AlertEmail {
    param(
        [object]$Results
    )

    if (-not $EmailAlert -or -not $SMTPServer) {
        return
    }

    $Subject = "WARNUNG: Copilot auf $env:COMPUTERNAME erkannt"
    $Body = @"
Copilot-Ueberwachung hat potenzielle Probleme erkannt:

Computer: $env:COMPUTERNAME
Zeitpunkt: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Ergebnisse:
-----------
App-Pakete: $($Results.AppPackages.Status)
Registry: $($Results.Registry.Status)
Kontextmenue: $($Results.ContextMenu.Status)
Hosts-Datei: $($Results.HostsFile.Status)
Firewall: $($Results.Firewall.Status)
Tasks: $($Results.Tasks.Status)
Office Connected Exp: $($Results.OfficeConnectedExp.Status)
Microsoft 365 Copilot: $($Results.Microsoft365Copilot.Status)

Gesamtstatus: $($Results.Overall)

Details siehe Log-Datei: $LogPath

---
Automatische Benachrichtigung vom Copilot-Monitoring-System
badata GmbH - IT Systems
"@

    try {
        Send-MailMessage -To $EmailAlert `
                         -From "copilot-monitoring@$env:USERDNSDOMAIN" `
                         -Subject $Subject `
                         -Body $Body `
                         -SmtpServer $SMTPServer `
                         -ErrorAction Stop

        Write-Log "E-Mail-Benachrichtigung gesendet an: $EmailAlert" -Type Success
    } catch {
        Write-Log "Fehler beim E-Mail-Versand: $($_.Exception.Message)" -Type Error
    }
}

function New-MonitoringTask {
    Write-Log "Erstelle Scheduled Task fuer monatliche Ueberpruefung..." -Type Info

    $TaskName = "Copilot-Monitoring"
    $TaskPath = "\badata\"
    $ScriptPath = $PSCommandPath

    # Pruefe ob Task bereits existiert
    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue
    if ($ExistingTask) {
        Write-Log "Task existiert bereits: $TaskPath$TaskName" -Type Warning
        if ($Force) {
            # Bei -Force: Task automatisch ueberschreiben
            Write-Log "Force-Modus: Task wird ueberschrieben" -Type Info
        } else {
            $Overwrite = Read-Host "Ueberschreiben? (J/N)"
            if ($Overwrite -ne "J" -and $Overwrite -ne "j") {
                Write-Log "Task-Erstellung abgebrochen" -Type Info
                return
            }
        }
        Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false
    }

    # Task-Action erstellen
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
        -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`""

    # Task-Trigger erstellen (monatlich, am 1. des Monats, 08:00 Uhr)
    $Trigger = New-ScheduledTaskTrigger -Monthly -DaysOfMonth 1 -At 08:00

    # Task-Einstellungen
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
                                               -DontStopIfGoingOnBatteries `
                                               -StartWhenAvailable `
                                               -RunOnlyIfNetworkAvailable

    # Task-Principal (als SYSTEM ausfuehren)
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    # Task registrieren
    try {
        Register-ScheduledTask -TaskName $TaskName `
                                -TaskPath $TaskPath `
                                -Action $Action `
                                -Trigger $Trigger `
                                -Settings $Settings `
                                -Principal $Principal `
                                -Description "Monatliche Ueberpruefung auf Microsoft Copilot Installation" `
                                -ErrorAction Stop

        Write-Log "Scheduled Task erfolgreich erstellt: $TaskPath$TaskName" -Type Success
        Write-Log "Naechste Ausfuehrung: $(Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath | Get-ScheduledTaskInfo | Select-Object -ExpandProperty NextRunTime)" -Type Info
    } catch {
        Write-Log "Fehler beim Erstellen des Scheduled Tasks: $($_.Exception.Message)" -Type Error
    }
}

# ========================================
# HAUPTPROGRAMM
# ========================================
Write-Log "========================================" -Type Info
Write-Log "Copilot-Praesenz-Ueberpruefung gestartet" -Type Info
Write-Log "========================================" -Type Info
Write-Log "Computer: $env:COMPUTERNAME" -Type Info
Write-Log "Benutzer: $env:USERNAME" -Type Info
Write-Log "" -Type Info

# Scheduled Task erstellen (falls Parameter gesetzt)
if ($CreateScheduledTask) {
    New-MonitoringTask
    exit 0
}

# Alle Ueberpruefungen durchfuehren
$Results = @{
    AppPackages = Test-AppPackages
    Registry = Test-RegistrySettings
    ContextMenu = Test-ContextMenu
    HostsFile = Test-HostsFile
    Firewall = Test-FirewallRules
    Tasks = Test-ScheduledTasks
    OfficeConnectedExp = Test-OfficeConnectedExperiences  # v2.1
    Microsoft365Copilot = Test-Microsoft365Copilot  # NEW v2.1.2
}

# Gesamtauswertung
Write-Log "" -Type Info
Write-Log "========================================" -Type Info
Write-Log "ZUSAMMENFASSUNG" -Type Info
Write-Log "========================================" -Type Info

$AllOK = $true
$Warnings = 0

foreach ($Key in $Results.Keys) {
    $Result = $Results[$Key]
    $Status = $Result.Status

    if ($Status -eq "NICHT_ANWENDBAR") {
        Write-Log "[$Key] NICHT ANWENDBAR" -Type Info
        # Nicht als Fehler werten
    } elseif ($Status -ne "OK") {
        $AllOK = $false
        if ($Status -eq "GEFUNDEN") {
            Write-Log "[$Key] COPILOT GEFUNDEN!" -Type Error
        } else {
            Write-Log "[$Key] $Status" -Type Warning
            $Warnings++
        }
    } else {
        Write-Log "[$Key] OK" -Type Success
    }
}

Write-Log "" -Type Info

if ($AllOK) {
    Write-Log "[OK] GESAMTSTATUS: SAUBER - Kein Copilot gefunden, alle Blockierungen aktiv" -Type Success
    $Results.Overall = "SAUBER"
    exit 0
} elseif ($Results.AppPackages.Status -eq "GEFUNDEN") {
    Write-Log "[X] GESAMTSTATUS: COPILOT GEFUNDEN - Sofortige Aktion erforderlich!" -Type Error
    $Results.Overall = "GEFUNDEN"

    # E-Mail-Alert senden
    Send-AlertEmail -Results $Results

    Write-Log "" -Type Info
    Write-Log "EMPFEHLUNG: Fuehren Sie Remove-CopilotComplete.ps1 erneut aus" -Type Warning

    exit 1
} else {
    Write-Log "[!] GESAMTSTATUS: BLOCKIERUNGEN UNVOLLSTAENDIG - $Warnings Warnung(en)" -Type Warning
    $Results.Overall = "UNVOLLSTAENDIG"

    # E-Mail-Alert senden (nur bei kritischen Faellen)
    if ($Warnings -gt 2) {
        Send-AlertEmail -Results $Results
    }

    exit 2
}
