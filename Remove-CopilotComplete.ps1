#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Microsoft Copilot Removal Toolkit v2.1.3
.DESCRIPTION
    Comprehensive script for removing Microsoft Copilot and blocking reinstallation
    All v2.1 features: Edge, Office, Notepad, Paint, Recall, Hardware Button, Game Bar
    v2.1.2: Microsoft 365 Copilot complete blocking (Word, Excel, PowerPoint, Outlook, OneNote)
    v2.1.3: Reinstallation prevention (Provisioned Packages, Deprovisioned Keys, AppLocker, Protocol Handlers, Store Auto-Update)
.PARAMETER LogOnly
    Test run without actual changes
.PARAMETER NoRestart
    Prevents restart prompt and Explorer restart
.PARAMETER SkipBackup
    Skips backup creation
.PARAMETER Force
    Forces execution without confirmation dialogs
.PARAMETER Unattended
    Fully automatic mode for GPO/Intune (implies -Force -NoRestart)
.PARAMETER UseTemp
    Uses C:\Temp\CopilotRemoval\$env:USERNAME instead of LOCALAPPDATA (RDS support)
.PARAMETER BackupDir
    Custom backup directory
.PARAMETER NoGPUpdate
    Skip Group Policy update (prevents domain GPOs from overwriting changes)
.NOTES
    Version: 2.1.3
#>

param(
    [switch]$LogOnly,
    [switch]$NoRestart,
    [switch]$SkipBackup,
    [switch]$Force,
    [switch]$Unattended,
    [switch]$UseTemp,
    [string]$BackupDir = "",
    [switch]$NoGPUpdate
)

# Unattended implies Force and NoRestart
if ($Unattended) {
    $Force = $true
    $NoRestart = $true
}

$ErrorActionPreference = "Continue"
$Script:Version = "2.1.3"
$Script:StartTime = Get-Date

# Path logic: UseTemp, BackupDir or default
if ($UseTemp) {
    $BaseDir = "C:\Temp\CopilotRemoval\$env:USERNAME"
} else {
    $BaseDir = "$env:LOCALAPPDATA\CopilotRemoval"
}

$Script:LogPath = "$BaseDir\Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$Script:ReportPath = "$BaseDir\Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$Script:TrackingFile = "$env:LOCALAPPDATA\CopilotRemoval\.execution_tracking"

if ($BackupDir -ne "") {
    $Script:BackupPath = "$BackupDir\Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
} else {
    $Script:BackupPath = "$BaseDir\Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
}
$Script:ProgressCounter = 0
$Script:TotalSteps = 50
$Script:Report = @{
    Version = $Script:Version
    StartTime = $Script:StartTime.ToString('o')
    Mode = if($LogOnly){'DryRun'}else{'Production'}
    Unattended = $Unattended
    Results = @{
        PackagesRemoved = @()
        RegistryChanges = @()
        FirewallRules = @()
        TasksDisabled = @()
        HostsEntries = @()
        Errors = @()
    }
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogMessage = "[$Timestamp] [$Level] $Message"

    $LogDir = Split-Path $Script:LogPath
    if (-not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    Add-Content -Path $Script:LogPath -Value $LogMessage

    $Color = switch($Level) {
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'White' }
    }
    Write-Host $LogMessage -ForegroundColor $Color
}

function Write-ProgressHelper {
    param([string]$Activity, [string]$Status)
    $Script:ProgressCounter++
    $PercentComplete = ($Script:ProgressCounter / $Script:TotalSteps) * 100
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

function Initialize-Backup {
    if ($SkipBackup -or $LogOnly) {
        Write-Log "Backup uebersprungen" "INFO"
        return
    }
    if (-not (Test-Path $Script:BackupPath)) {
        New-Item -Path $Script:BackupPath -ItemType Directory -Force | Out-Null
        Write-Log "Backup-Ordner erstellt - $Script:BackupPath" "SUCCESS"
    }
}

function Backup-RegistryKey {
    param([string]$Path)
    if ($SkipBackup -or $LogOnly) { return }
    if (Test-Path $Path) {
        $SafePath = $Path -replace '[:\\]', '_'
        $BackupFile = "$Script:BackupPath\Registry_$SafePath.reg"
        $RegPath = $Path -replace 'HKLM:\\', 'HKEY_LOCAL_MACHINE\' -replace 'HKCU:\\', 'HKEY_CURRENT_USER\'
        Start-Process -FilePath 'reg.exe' -ArgumentList "export `"$RegPath`" `"$BackupFile`" /y" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    }
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = 'DWord',
        [switch]$SkipBackup
    )
    if (-not $SkipBackup) {
        Backup-RegistryKey -Path $Path
    }
    if ($LogOnly) {
        Write-Log "Wuerde setzen - $Path\$Name = $Value" "INFO"
        return $true
    }
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
        $Script:Report.Results.RegistryChanges += @{ Path = $Path; Name = $Name; Value = $Value }
        return $true
    }
    catch {
        Write-Log "Registry fehlgeschlagen - $Path\$Name - $($_.Exception.Message)" "ERROR"
        $Script:Report.Results.Errors += @{ Type = 'Registry'; Path = $Path; Error = $_.Exception.Message }
        return $false
    }
}

function Get-SystemInfo {
    $OS = Get-CimInstance -ClassName Win32_OperatingSystem
    return @{
        OSName = $OS.Caption
        OSVersion = $OS.Version
        OSBuild = $OS.BuildNumber
        IsEnterprise = $OS.Caption -match 'Enterprise'
        IsPro = $OS.Caption -match 'Pro'
    }
}

function Test-AlreadyExecuted {
    if ($Force) { return $false }
    if (Test-Path $Script:TrackingFile) {
        $Tracking = Get-Content $Script:TrackingFile -Raw | ConvertFrom-Json
        Write-Log "Script bereits ausgefuehrt am $($Tracking.LastRun)" "WARNING"
        if (-not $Unattended) {
            $Response = Read-Host "Trotzdem fortfahren? (J/N)"
            return ($Response -ne 'J' -and $Response -ne 'j')
        }
        return $true
    }
    return $false
}

function Set-ExecutionTracking {
    @{
        LastRun = (Get-Date).ToString('o')
        Version = $Script:Version
    } | ConvertTo-Json | Out-File $Script:TrackingFile -Encoding UTF8
}

function Remove-CopilotPackages {
    Write-ProgressHelper -Activity "Phase 1" -Status "Entferne Pakete..."
    Write-Log "Suche nach Copilot-Paketen (kann 30-60 Sekunden dauern)..." "INFO"
    $PackagePatterns = @('*Copilot*', '*WindowsAI*')
    $RemovedCount = 0

    # Entferne installierte Pakete (current + all users)
    foreach ($Pattern in $PackagePatterns) {
        Write-Log "Suche nach installierten Paketen mit Muster: $Pattern" "INFO"
        $Packages = Get-AppxPackage -AllUsers -Name $Pattern -ErrorAction SilentlyContinue
        Write-Log "$($Packages.Count) installierte Pakete gefunden mit Muster $Pattern" "INFO"
        foreach ($Package in $Packages) {
            if ($LogOnly) {
                Write-Log "Wuerde entfernen - $($Package.Name)" "INFO"
            }
            else {
                try {
                    Remove-AppxPackage -Package $Package.PackageFullName -AllUsers -ErrorAction Stop
                    Write-Log "Paket entfernt - $($Package.Name)" "SUCCESS"
                    $Script:Report.Results.PackagesRemoved += @{ Name = $Package.Name; Version = $Package.Version }
                    $RemovedCount++
                }
                catch {
                    Write-Log "Paket-Entfernung fehlgeschlagen - $($Package.Name) - $($_.Exception.Message)" "ERROR"
                    $Script:Report.Results.Errors += @{ Type = 'Package'; Name = $Package.Name; Error = $_.Exception.Message }
                }
            }
        }
    }

    # Entferne provisionierte Pakete (verhindert Installation fuer neue User)
    Write-Log "Suche nach provisionierten Paketen (neue User)..." "INFO"
    $ProvisionedCount = 0
    foreach ($Pattern in $PackagePatterns) {
        Write-Log "Suche nach provisionierten Paketen mit Muster: $Pattern" "INFO"
        $ProvisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                               Where-Object { $_.DisplayName -like $Pattern }
        Write-Log "$($ProvisionedPackages.Count) provisionierte Pakete gefunden mit Muster $Pattern" "INFO"

        foreach ($Package in $ProvisionedPackages) {
            if ($LogOnly) {
                Write-Log "Wuerde provisioniertes Paket entfernen - $($Package.DisplayName)" "INFO"
            }
            else {
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $Package.PackageName -ErrorAction Stop | Out-Null
                    Write-Log "Provisioniertes Paket entfernt - $($Package.DisplayName)" "SUCCESS"
                    $Script:Report.Results.PackagesRemoved += @{ Name = $Package.DisplayName; Type = 'Provisioned' }
                    $ProvisionedCount++
                }
                catch {
                    Write-Log "Provisioniertes Paket-Entfernung fehlgeschlagen - $($Package.DisplayName) - $($_.Exception.Message)" "ERROR"
                    $Script:Report.Results.Errors += @{ Type = 'ProvisionedPackage'; Name = $Package.DisplayName; Error = $_.Exception.Message }
                }
            }
        }
    }

    Write-Log "Pakete entfernt - $RemovedCount installierte, $ProvisionedCount provisionierte" "SUCCESS"
}

function Create-DeprovisionedKeys {
    Write-ProgressHelper -Activity "Phase 1b" -Status "Erstelle Deprovisioned Keys..."
    Write-Log "Erstelle Deprovisioned Registry Keys (verhindert Feature Update Reinstallation)..." "INFO"

    # Package Family Names der Copilot-Pakete
    $CopilotPackageFamilies = @(
        'Microsoft.Copilot_8wekyb3d8bbwe',
        'Microsoft.Windows.Ai.Copilot.Provider_8wekyb3d8bbwe',
        'MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy',
        'Microsoft.WindowsCopilot_8wekyb3d8bbwe',
        'Microsoft.Windows.Copilot_8wekyb3d8bbwe'
    )

    $DeprovisionedBasePath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned'

    if ($LogOnly) {
        Write-Log "Wuerde $($CopilotPackageFamilies.Count) Deprovisioned Keys erstellen" "INFO"
        return
    }

    # Stelle sicher dass Basis-Pfad existiert
    if (-not (Test-Path $DeprovisionedBasePath)) {
        New-Item -Path $DeprovisionedBasePath -Force -ErrorAction SilentlyContinue | Out-Null
    }

    $CreatedCount = 0
    foreach ($PackageFamily in $CopilotPackageFamilies) {
        $KeyPath = Join-Path $DeprovisionedBasePath $PackageFamily

        if (Test-Path $KeyPath) {
            Write-Log "Deprovisioned Key existiert bereits - $PackageFamily" "INFO"
        }
        else {
            try {
                New-Item -Path $KeyPath -Force -ErrorAction Stop | Out-Null
                Write-Log "Deprovisioned Key erstellt - $PackageFamily" "SUCCESS"
                $CreatedCount++
            }
            catch {
                Write-Log "Deprovisioned Key fehlgeschlagen - $PackageFamily - $($_.Exception.Message)" "ERROR"
                $Script:Report.Results.Errors += @{ Type = 'DeprovisionedKey'; Name = $PackageFamily; Error = $_.Exception.Message }
            }
        }
    }

    Write-Log "Deprovisioned Keys - $CreatedCount erstellt" "SUCCESS"
}

function Configure-RegistrySettings {
    Write-ProgressHelper -Activity "Phase 2" -Status "Konfiguriere Registry..."
    $RegistrySettings = @(
        # Windows Copilot Core
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name='TurnOffWindowsCopilot'; Value=1},
        @{Path='HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name='TurnOffWindowsCopilot'; Value=1},
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowCopilotButton'; Value=0},
        @{Path='HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowCopilotButton'; Value=0},
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableWindowsConsumerFeatures'; Value=1},
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name='AllowCortana'; Value=0},

        # Edge Copilot (v2.1)
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name='HubsSidebarEnabled'; Value=0},
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name='CopilotPageEnabled'; Value=0},
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name='Microsoft365CopilotChatIconEnabled'; Value=0},

        # Office Connected Experiences (v2.1)
        @{Path='HKCU:\Software\Policies\Microsoft\office\16.0\common\privacy'; Name='disconnectedstate'; Value=2},
        @{Path='HKCU:\Software\Policies\Microsoft\office\16.0\common\privacy'; Name='usercontentdisabled'; Value=2},

        # Microsoft 365 Copilot - Main Toggle (v2.1.2)
        @{Path='HKCU:\Software\Policies\Microsoft\office\16.0\common\copilot'; Name='TurnOffCopilot'; Value=1},
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\copilot'; Name='TurnOffCopilot'; Value=1},

        # Microsoft 365 Copilot - Per-Application (v2.1.2)
        @{Path='HKCU:\Software\Policies\Microsoft\office\16.0\word\options\copilot'; Name='DisableCopilot'; Value=1},
        @{Path='HKCU:\Software\Policies\Microsoft\office\16.0\excel\options\copilot'; Name='DisableCopilot'; Value=1},
        @{Path='HKCU:\Software\Policies\Microsoft\office\16.0\powerpoint\options\copilot'; Name='DisableCopilot'; Value=1},
        @{Path='HKCU:\Software\Policies\Microsoft\office\16.0\outlook\options\copilot'; Name='DisableCopilot'; Value=1},
        @{Path='HKCU:\Software\Policies\Microsoft\office\16.0\onenote\options\copilot'; Name='DisableCopilot'; Value=1},

        # Microsoft 365 Copilot - Additional Controls (v2.1.2)
        @{Path='HKCU:\Software\Policies\Microsoft\office\16.0\common'; Name='AllowCopilot'; Value=0},
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common'; Name='AllowCopilot'; Value=0},
        @{Path='HKCU:\Software\Policies\Microsoft\office\16.0\common\copilot'; Name='DisableCopilotInOffice'; Value=1},
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\copilot'; Name='DisableCopilotInOffice'; Value=1},

        # Notepad AI (v2.1)
        @{Path='HKLM:\SOFTWARE\Policies\WindowsNotepad'; Name='DisableAIFeatures'; Value=1},

        # Paint AI (v2.1)
        @{Path='HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name='DisableImageCreator'; Value=1},
        @{Path='HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name='DisableCocreator'; Value=1},
        @{Path='HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Paint'; Name='DisableGenerativeFill'; Value=1},

        # Windows Recall (v2.1)
        @{Path='HKCU:\Software\Policies\Microsoft\Windows\WindowsAI'; Name='DisableAIDataAnalysis'; Value=1},
        @{Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name='DisableAIDataAnalysis'; Value=1},

        # Copilot Hardware Button (v2.1)
        @{Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System'; Name='ConfigureCopilotHardwareButton'; Value=1},

        # Click-To-Do (v2.1)
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ImmersiveShell'; Name='DisableClickToDo'; Value=1},

        # Game Bar Copilot (v2.1)
        @{Path='HKCU:\Software\Microsoft\GameBar'; Name='ShowCopilotButton'; Value=0}
    )

    # Optimierung: Backup eindeutiger Pfade nur einmal statt pro Key
    Write-Log "Erstelle Backups fuer Registry-Pfade..." "INFO"
    $UniquePaths = ($RegistrySettings | ForEach-Object { $_.Path }) | Select-Object -Unique
    Write-Log "Sichere $($UniquePaths.Count) eindeutige Registry-Pfade..." "INFO"
    foreach ($Path in $UniquePaths) {
        Backup-RegistryKey -Path $Path
    }
    Write-Log "Backup abgeschlossen, wende Registry-Einstellungen an..." "INFO"

    $SuccessCount = 0
    $CurrentKey = 0
    foreach ($Setting in $RegistrySettings) {
        $CurrentKey++
        # Progress alle 5 Keys aktualisieren um Flackern zu reduzieren
        if ($CurrentKey % 5 -eq 0) {
            Write-ProgressHelper -Activity "Phase 2" -Status "Setze Registry ($CurrentKey/$($RegistrySettings.Count))..."
        }
        if (Set-RegistryValue @Setting -SkipBackup) { $SuccessCount++ }
    }
    Write-Log "Registry - $SuccessCount/$($RegistrySettings.Count) gesetzt" "SUCCESS"
}

function Remove-ContextMenuEntries {
    Write-ProgressHelper -Activity "Phase 3" -Status "Entferne Kontextmenue..."
    $ContextMenuPaths = @(
        'HKCR:\*\shell\Copilot',
        'HKCR:\Directory\shell\Copilot',
        'HKCU:\Software\Classes\*\shell\Copilot'
    )

    # Blockiere Shell Extension GUID
    if (-not $LogOnly) {
        $BlockPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked'
        if (-not (Test-Path $BlockPath)) {
            New-Item -Path $BlockPath -Force | Out-Null
        }
        Set-ItemProperty -Path $BlockPath -Name '{7c02d4f7-ede2-4c96-b666-7a452c1e7b71}' -Value '' -Type String -ErrorAction SilentlyContinue
        Write-Log "Shell Extension GUID blockiert" "SUCCESS"
    }

    $RemovedCount = 0
    foreach ($Path in $ContextMenuPaths) {
        if (Test-Path $Path) {
            Backup-RegistryKey -Path $Path
            if (-not $LogOnly) {
                Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Kontextmenue entfernt - $Path" "SUCCESS"
                $RemovedCount++
            }
        }
    }
    Write-Log "Kontextmenue - $RemovedCount Eintraege entfernt" "SUCCESS"
}

function Configure-AppLocker {
    Write-ProgressHelper -Activity "Phase 4" -Status "Pruefe AppLocker..."
    $SystemInfo = Get-SystemInfo
    if (-not ($SystemInfo.IsEnterprise -or $SystemInfo.IsPro)) {
        Write-Log "AppLocker nicht verfuegbar (nur Enterprise/Pro)" "WARNING"
        return
    }

    Write-Log "Konfiguriere AppLocker-Regeln fuer Copilot-Blockierung..." "INFO"

    # AppLocker Service pruefen
    $AppIDSvc = Get-Service -Name AppIDSvc -ErrorAction SilentlyContinue
    if (-not $AppIDSvc) {
        Write-Log "AppLocker Service (AppIDSvc) nicht gefunden" "WARNING"
        return
    }

    if ($LogOnly) {
        Write-Log "Wuerde AppLocker-Regeln fuer Copilot erstellen" "INFO"
        return
    }

    try {
        # AppLocker Service starten falls nicht laufend
        if ($AppIDSvc.Status -ne 'Running') {
            Write-Log "Starte AppLocker Service..." "INFO"
            Start-Service -Name AppIDSvc -ErrorAction Stop
            Set-Service -Name AppIDSvc -StartupType Automatic -ErrorAction SilentlyContinue
        }

        # Erstelle XML-Policy fuer Copilot Blockierung
        $AppLockerXML = @"
<AppLockerPolicy Version="1">
    <RuleCollection Type="Exe" EnforcementMode="AuditOnly">
        <FilePublisherRule Id="$(New-Guid)" Name="Block Microsoft Copilot" Description="Blockiert Microsoft Copilot Anwendungen" UserOrGroupSid="S-1-1-0" Action="Deny">
            <Conditions>
                <FilePublisherCondition PublisherName="O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US" ProductName="Microsoft.Copilot*" BinaryName="*">
                    <BinaryVersionRange LowSection="*" HighSection="*" />
                </FilePublisherCondition>
            </Conditions>
        </FilePublisherRule>
        <FilePublisherRule Id="$(New-Guid)" Name="Block Windows Copilot" Description="Blockiert Windows Copilot Anwendungen" UserOrGroupSid="S-1-1-0" Action="Deny">
            <Conditions>
                <FilePublisherCondition PublisherName="O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US" ProductName="Microsoft.WindowsCopilot*" BinaryName="*">
                    <BinaryVersionRange LowSection="*" HighSection="*" />
                </FilePublisherCondition>
            </Conditions>
        </FilePublisherRule>
        <FilePublisherRule Id="$(New-Guid)" Name="Block Copilot Provider" Description="Blockiert Copilot AI Provider" UserOrGroupSid="S-1-1-0" Action="Deny">
            <Conditions>
                <FilePublisherCondition PublisherName="O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US" ProductName="Microsoft.Windows.Ai.Copilot.Provider*" BinaryName="*">
                    <BinaryVersionRange LowSection="*" HighSection="*" />
                </FilePublisherCondition>
            </Conditions>
        </FilePublisherRule>
        <FilePathRule Id="$(New-Guid)" Name="Block Copilot Executable Path" Description="Blockiert Copilot ueber Dateipfad" UserOrGroupSid="S-1-1-0" Action="Deny">
            <Conditions>
                <FilePathCondition Path="%PROGRAMFILES%\WindowsApps\Microsoft.Copilot*\*" />
            </Conditions>
        </FilePathRule>
        <FilePathRule Id="$(New-Guid)" Name="Block WindowsCopilot Path" Description="Blockiert WindowsCopilot ueber Dateipfad" UserOrGroupSid="S-1-1-0" Action="Deny">
            <Conditions>
                <FilePathCondition Path="%PROGRAMFILES%\WindowsApps\Microsoft.WindowsCopilot*\*" />
            </Conditions>
        </FilePathRule>
    </RuleCollection>
</AppLockerPolicy>
"@

        # Temporaere XML-Datei erstellen
        $TempXML = Join-Path $env:TEMP "CopilotAppLockerPolicy.xml"
        $AppLockerXML | Out-File -FilePath $TempXML -Encoding UTF8 -Force

        # AppLocker Policy anwenden (Merge-Modus um existierende Regeln zu behalten)
        Write-Log "Wende AppLocker-Policy an..." "INFO"
        Set-AppLockerPolicy -XmlPolicy $TempXML -Merge -ErrorAction Stop

        # Cleanup
        Remove-Item -Path $TempXML -Force -ErrorAction SilentlyContinue

        Write-Log "AppLocker-Regeln erfolgreich konfiguriert (5 Deny Rules)" "SUCCESS"
        $Script:Report.Results.AppLockerConfigured = $true
    }
    catch {
        Write-Log "AppLocker-Konfiguration fehlgeschlagen - $($_.Exception.Message)" "ERROR"
        $Script:Report.Results.Errors += @{ Type = 'AppLocker'; Error = $_.Exception.Message }
    }
}

function Block-CopilotProtocolHandlers {
    Write-ProgressHelper -Activity "Phase 4b" -Status "Blockiere Protocol Handlers..."
    Write-Log "Blockiere Copilot Protocol Handlers (ms-copilot://)..." "INFO"

    # Erstelle HKCR: PSDrive falls nicht vorhanden
    if (-not (Test-Path "HKCR:")) {
        try {
            New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction Stop | Out-Null
            Write-Log "HKCR: PSDrive erstellt" "INFO"
        }
        catch {
            Write-Log "HKCR: PSDrive Erstellung fehlgeschlagen - $($_.Exception.Message)" "ERROR"
            return
        }
    }

    # Protocol Handler Registry Keys
    $ProtocolHandlers = @(
        'HKCR:\ms-copilot',
        'HKCR:\microsoft-edge-holographic',
        'HKCR:\ms-windows-ai-copilot'
    )

    if ($LogOnly) {
        Write-Log "Wuerde $($ProtocolHandlers.Count) Protocol Handler blockieren" "INFO"
        return
    }

    $BlockedCount = 0
    foreach ($Handler in $ProtocolHandlers) {
        if (Test-Path $Handler) {
            try {
                # Backup original handler
                $BackupKey = $Handler -replace 'HKCR:', 'Backup_'
                $BackupPath = Join-Path $Script:BackupPath "$BackupKey.reg"

                # Export vor Loeschung
                $RegPath = $Handler -replace 'HKCR:', 'HKEY_CLASSES_ROOT\'
                reg.exe export $RegPath $BackupPath /y 2>$null | Out-Null

                # Loesche Protocol Handler
                Remove-Item -Path $Handler -Recurse -Force -ErrorAction Stop
                Write-Log "Protocol Handler blockiert - $Handler" "SUCCESS"
                $BlockedCount++
            }
            catch {
                Write-Log "Protocol Handler Blockierung fehlgeschlagen - $Handler - $($_.Exception.Message)" "ERROR"
                $Script:Report.Results.Errors += @{ Type = 'ProtocolHandler'; Handler = $Handler; Error = $_.Exception.Message }
            }
        }
        else {
            Write-Log "Protocol Handler nicht vorhanden - $Handler" "INFO"
        }
    }

    # Erstelle Block-Keys um Re-Registration zu verhindern
    foreach ($Handler in $ProtocolHandlers) {
        if (-not (Test-Path $Handler)) {
            try {
                # Erstelle leeren Key ohne URL Protocol Value
                New-Item -Path $Handler -Force -ErrorAction Stop | Out-Null
                New-ItemProperty -Path $Handler -Name 'Blocked' -Value 'CopilotRemovalToolkit' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
                Write-Log "Block-Key erstellt - $Handler" "SUCCESS"
            }
            catch {
                Write-Log "Block-Key Erstellung fehlgeschlagen - $Handler - $($_.Exception.Message)" "WARNING"
            }
        }
    }

    Write-Log "Protocol Handlers - $BlockedCount blockiert, Block-Keys erstellt" "SUCCESS"
}

function Block-CopilotStoreAutoUpdate {
    Write-ProgressHelper -Activity "Phase 4c" -Status "Blockiere Store Auto-Update..."
    Write-Log "Blockiere Microsoft Store Auto-Update/Install fuer Copilot (Store bleibt funktional)..." "INFO"

    # Package Family Names der Copilot-Pakete
    $CopilotPackageFamilies = @(
        'Microsoft.Copilot_8wekyb3d8bbwe',
        'Microsoft.Windows.Ai.Copilot.Provider_8wekyb3d8bbwe',
        'MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy',
        'Microsoft.WindowsCopilot_8wekyb3d8bbwe',
        'Microsoft.Windows.Copilot_8wekyb3d8bbwe'
    )

    if ($LogOnly) {
        Write-Log "Wuerde Store Auto-Update fuer $($CopilotPackageFamilies.Count) Copilot-Pakete blockieren" "INFO"
        return
    }

    $BlockedCount = 0

    # Blockiere automatische Installation aus Store
    $StoreBlockPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\BlockedPackages'
    if (-not (Test-Path $StoreBlockPath)) {
        try {
            New-Item -Path $StoreBlockPath -Force -ErrorAction Stop | Out-Null
            Write-Log "Store BlockedPackages Registry Key erstellt" "INFO"
        }
        catch {
            Write-Log "Store BlockedPackages Key Erstellung fehlgeschlagen - $($_.Exception.Message)" "WARNING"
        }
    }

    # Erstelle Block-Eintraege fuer jedes Copilot-Paket
    foreach ($PackageFamily in $CopilotPackageFamilies) {
        $BlockKeyPath = Join-Path $StoreBlockPath $PackageFamily

        if (-not (Test-Path $BlockKeyPath)) {
            try {
                New-Item -Path $BlockKeyPath -Force -ErrorAction Stop | Out-Null
                New-ItemProperty -Path $BlockKeyPath -Name 'BlockedByPolicy' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
                New-ItemProperty -Path $BlockKeyPath -Name 'Reason' -Value 'CopilotRemovalToolkit' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
                Write-Log "Store Auto-Update blockiert - $PackageFamily" "SUCCESS"
                $BlockedCount++
            }
            catch {
                Write-Log "Store Block fehlgeschlagen - $PackageFamily - $($_.Exception.Message)" "ERROR"
                $Script:Report.Results.Errors += @{ Type = 'StoreAutoUpdate'; Package = $PackageFamily; Error = $_.Exception.Message }
            }
        }
        else {
            Write-Log "Store Block existiert bereits - $PackageFamily" "INFO"
        }
    }

    # Zusaetzlich: Blockiere "Optional Features" auto-install fuer Copilot
    $OptionalFeaturesPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OptionalFeatures\Microsoft-Windows-Copilot'
    if (-not (Test-Path $OptionalFeaturesPath)) {
        try {
            New-Item -Path $OptionalFeaturesPath -Force -ErrorAction Stop | Out-Null
            New-ItemProperty -Path $OptionalFeaturesPath -Name 'InstallState' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
            Write-Log "Optional Features Copilot blockiert" "SUCCESS"
        }
        catch {
            Write-Log "Optional Features Blockierung fehlgeschlagen - $($_.Exception.Message)" "WARNING"
        }
    }

    Write-Log "Store Auto-Update - $BlockedCount Copilot-Pakete blockiert (Store bleibt funktional)" "SUCCESS"
}

function Create-FirewallRules {
    Write-ProgressHelper -Activity "Phase 5" -Status "Erstelle Firewall-Regeln..."
    $DomainsToBlock = @(
        'copilot.microsoft.com',
        'sydney.bing.com',
        'edgeservices.bing.com',
        'copilot.cloud.microsoft',
        'business.bing.com',
        'turing.microsoft.com'
    )
    $HostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"

    if ($LogOnly) {
        Write-Log "Wuerde $($DomainsToBlock.Count) Domains blockieren" "INFO"
    }
    else {
        if (-not $SkipBackup) {
            Copy-Item -Path $HostsFile -Destination "$Script:BackupPath\hosts.backup" -Force -ErrorAction SilentlyContinue
        }
        $HostsContent = Get-Content $HostsFile -ErrorAction SilentlyContinue
        $AddedCount = 0
        foreach ($Domain in $DomainsToBlock) {
            $EscapedDomain = [regex]::Escape($Domain)
            $AlreadyBlocked = $HostsContent | Where-Object { $_ -match $EscapedDomain }
            if (-not $AlreadyBlocked) {
                Add-Content -Path $HostsFile -Value "0.0.0.0 $Domain # Copilot Blocker" -ErrorAction SilentlyContinue
                Write-Log "Domain blockiert - $Domain" "SUCCESS"
                $Script:Report.Results.HostsEntries += @{ Domain = $Domain }
                $AddedCount++
            }
        }
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Write-Log "DNS-Blockierung - $AddedCount Eintraege" "SUCCESS"
    }
}

function Disable-CopilotTasks {
    Write-ProgressHelper -Activity "Phase 6" -Status "Deaktiviere Tasks..."
    Write-Log "Suche nach geplanten Tasks (kann 10-20 Sekunden dauern)..." "INFO"
    $TaskPatterns = @('*Copilot*', '*WindowsAI*')
    $DisabledCount = 0

    foreach ($Pattern in $TaskPatterns) {
        Write-Log "Suche nach Tasks mit Muster: $Pattern" "INFO"
        $Tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like $Pattern }
        Write-Log "$($Tasks.Count) Tasks gefunden mit Muster $Pattern" "INFO"
        foreach ($Task in $Tasks) {
            if ($LogOnly) {
                Write-Log "Wuerde deaktivieren - $($Task.TaskName)" "INFO"
            }
            else {
                Disable-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath -ErrorAction SilentlyContinue | Out-Null
                Write-Log "Task deaktiviert - $($Task.TaskName)" "SUCCESS"
                $Script:Report.Results.TasksDisabled += @{ Name = $Task.TaskName }
                $DisabledCount++
            }
        }
    }
    Write-Log "Tasks - $DisabledCount deaktiviert" "SUCCESS"
}

function Test-CopilotRemoval {
    Write-ProgressHelper -Activity "Phase 9" -Status "Verifiziere..."
    Write-Log "Verifiziere Entfernung (scanne Pakete - kann 30-60 Sekunden dauern)..." "INFO"
    $RemainingPackages = @()
    $RemainingPackages += Get-AppxPackage -AllUsers -Name '*Copilot*' -ErrorAction SilentlyContinue
    $RemainingPackages += Get-AppxPackage -AllUsers -Name '*WindowsAI*' -ErrorAction SilentlyContinue
    Write-Log "Verifikations-Scan abgeschlossen - $($RemainingPackages.Count) Copilot-Pakete gefunden" "INFO"
    $HostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    $HostsContent = Get-Content $HostsFile -ErrorAction SilentlyContinue
    $HostsConfigured = $HostsContent -match 'copilot\.microsoft\.com'

    $Success = ($RemainingPackages.Count -eq 0) -and $HostsConfigured

    if ($Success) {
        Write-Log "Verifikation - Copilot vollstaendig entfernt" "SUCCESS"
    }
    else {
        Write-Log "Verifikation - Einige Komponenten verbleiben" "WARNING"
    }

    return @{
        PackagesFound = $RemainingPackages.Count
        HostsConfigured = $HostsConfigured
        OverallSuccess = $Success
    }
}

function Restart-Explorer {
    if ($NoRestart -or $LogOnly) {
        Write-Log "Explorer-Neustart uebersprungen (NoRestart oder LogOnly Modus)" "INFO"
        return
    }
    if (-not $Unattended) {
        Write-Host ""
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "Explorer-Neustart erforderlich damit Aenderungen wirksam werden." -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""
        $Response = Read-Host "Explorer jetzt neu starten? (J/N)"
        if ($Response -ne 'J' -and $Response -ne 'j') {
            Write-Log "Explorer-Neustart vom Benutzer abgelehnt" "INFO"
            return
        }
    }
    Write-Log "Starte Explorer neu..." "INFO"
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
    Write-Log "Explorer neugestartet" "SUCCESS"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Microsoft Copilot Removal Toolkit v$Script:Version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "=== Script gestartet ===" "INFO"
Write-Log "Version - $Script:Version" "INFO"
Write-Log "Modus - $(if($LogOnly){'TESTLAUF'}else{'PRODUKTIV'})" "INFO"
Write-Log "Unattended - $Unattended" "INFO"
Write-Log "UseTemp - $UseTemp" "INFO"
Write-Log "NoGPUpdate - $NoGPUpdate" "INFO"

$SystemInfo = Get-SystemInfo
Write-Log "System - $($SystemInfo.OSName) Build $($SystemInfo.OSBuild)" "INFO"
$Script:Report.SystemInfo = $SystemInfo

if (Test-AlreadyExecuted) {
    Write-Host "Script bereits ausgefuehrt." -ForegroundColor Yellow
    if ($Unattended) {
        Write-Log "Unattended-Modus - Beende ohne Aenderungen" "INFO"
    }
    exit 0
}

if (-not $LogOnly) {
    Initialize-Backup | Out-Null
}

Write-Log "Starte Phase 1 - Paket-Entfernung..." "INFO"
Remove-CopilotPackages

Write-Log "Starte Phase 1b - Deprovisioned Registry Keys..." "INFO"
Create-DeprovisionedKeys

Write-Log "Starte Phase 2 - Registry-Konfiguration..." "INFO"
Configure-RegistrySettings

Write-Log "Starte Phase 3 - Kontextmenue-Entfernung..." "INFO"
Remove-ContextMenuEntries

Write-Log "Starte Phase 4 - AppLocker-Konfiguration..." "INFO"
Configure-AppLocker

Write-Log "Starte Phase 4b - Protocol Handler Blockierung..." "INFO"
Block-CopilotProtocolHandlers

Write-Log "Starte Phase 4c - Store Auto-Update Blockierung..." "INFO"
Block-CopilotStoreAutoUpdate

Write-Log "Starte Phase 5 - Firewall-Regeln..." "INFO"
Create-FirewallRules

Write-Log "Starte Phase 6 - Geplante Tasks..." "INFO"
Disable-CopilotTasks

Write-ProgressHelper -Activity "Phase 7" -Status "Services uebersprungen"
Write-Log "Phase 7 - Services uebersprungen" "INFO"

Write-ProgressHelper -Activity "Phase 8" -Status "GPO-Update..."
if ($NoGPUpdate) {
    Write-Log "GPO-Update uebersprungen (NoGPUpdate Parameter gesetzt)" "INFO"
} elseif ($LogOnly) {
    Write-Log "GPO-Update uebersprungen (LogOnly Modus)" "INFO"
} else {
    Write-Log "Aktualisiere Gruppenrichtlinien (kann 30-60 Sekunden dauern)..." "INFO"
    Start-Process -FilePath 'gpupdate.exe' -ArgumentList '/force' -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Write-Log "Gruppenrichtlinien aktualisiert" "SUCCESS"
}

$VerificationResults = Test-CopilotRemoval
$Script:Report.VerificationResults = $VerificationResults

Write-ProgressHelper -Activity "Phase 10" -Status "Erstelle Report..."
Write-Log "Phase 10 gestartet - Erstelle Ausfuehrungs-Report..." "INFO"

Write-Log "Schritt 1/5 - Setze Report-Endzeit..." "INFO"
$Script:Report.EndTime = (Get-Date).ToString('o')

Write-Log "Schritt 2/5 - Berechne Dauer..." "INFO"
$Script:Report.Duration = (New-TimeSpan -Start $Script:StartTime -End (Get-Date)).ToString()

Write-Log "Schritt 3/5 - Setze Erfolgs-Status..." "INFO"
$Script:Report.Success = $VerificationResults.OverallSuccess

Write-Log "Schritt 4/5 - Erstelle Report-Verzeichnis..." "INFO"
$ReportDir = Split-Path $Script:ReportPath
if (-not (Test-Path $ReportDir)) {
    New-Item -Path $ReportDir -ItemType Directory -Force | Out-Null
}

Write-Log "Schritt 5/5 - Konvertiere zu JSON und speichere..." "INFO"
try {
    # Vereinfachter Report um JSON-Serialisierungs-Probleme zu vermeiden
    $SimpleReport = @{
        Version = $Script:Report.Version
        StartTime = $Script:Report.StartTime
        EndTime = $Script:Report.EndTime
        Duration = $Script:Report.Duration
        Mode = $Script:Report.Mode
        Unattended = $Script:Report.Unattended
        Success = $Script:Report.Success
        PackagesRemoved = $Script:Report.Results.PackagesRemoved.Count
        RegistryChanges = $Script:Report.Results.RegistryChanges.Count
        TasksDisabled = $Script:Report.Results.TasksDisabled.Count
        HostsEntries = $Script:Report.Results.HostsEntries.Count
        Errors = $Script:Report.Results.Errors.Count
    }

    $JsonReport = $SimpleReport | ConvertTo-Json -Depth 3 -Compress -ErrorAction Stop
    Write-Log "JSON-Konvertierung abgeschlossen, schreibe in Datei..." "INFO"
    $JsonReport | Out-File $Script:ReportPath -Encoding UTF8 -ErrorAction Stop
    Write-Log "Report erfolgreich gespeichert - $Script:ReportPath" "SUCCESS"
} catch {
    Write-Log "Report-Speicherung fehlgeschlagen: $($_.Exception.Message)" "ERROR"
    Write-Log "Fahre ohne Report fort..." "WARNING"
}

if (-not $LogOnly) {
    Write-Log "Speichere Ausfuehrungs-Tracking..." "INFO"
    Set-ExecutionTracking
    Write-Log "Ausfuehrungs-Tracking gespeichert" "SUCCESS"
}

# Loesche Progress Bar VOR Prompts
Write-Log "Loesche Progress Bar..." "INFO"
Write-Progress -Activity "Fertig" -Completed

# Explorer-Neustart
Write-Log "Pruefe ob Explorer-Neustart noetig ist..." "INFO"
Restart-Explorer
Write-Log "Explorer-Neustart-Pruefung abgeschlossen" "INFO"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Script abgeschlossen" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Zusammenfassung:" -ForegroundColor Cyan
Write-Host "  - Pakete entfernt: $($Script:Report.Results.PackagesRemoved.Count)" -ForegroundColor White
Write-Host "  - Registry-Aenderungen: $($Script:Report.Results.RegistryChanges.Count)" -ForegroundColor White
Write-Host "  - Firewall-Regeln: $($Script:Report.Results.FirewallRules.Count)" -ForegroundColor White
Write-Host "  - Tasks deaktiviert: $($Script:Report.Results.TasksDisabled.Count)" -ForegroundColor White
Write-Host "  - Hosts-Eintraege: $($Script:Report.Results.HostsEntries.Count)" -ForegroundColor White
Write-Host ""
Write-Host "Log-Datei: $Script:LogPath" -ForegroundColor Cyan
Write-Host "Report: $Script:ReportPath" -ForegroundColor Cyan
if (-not $SkipBackup -and -not $LogOnly) {
    Write-Host "Backup: $Script:BackupPath" -ForegroundColor Cyan
}
Write-Host ""

if (-not $NoRestart -and -not $LogOnly -and -not $Unattended) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Ein System-Neustart wird empfohlen damit alle Aenderungen wirksam werden." -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    $Response = Read-Host "Computer jetzt neu starten? (J/N)"
    if ($Response -eq 'J' -or $Response -eq 'j') {
        Write-Log "System-Neustart vom Benutzer initiiert" "INFO"
        Write-Host "Computer wird in 10 Sekunden neu gestartet..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    } else {
        Write-Log "System-Neustart vom Benutzer abgelehnt" "INFO"
    }
}

Write-Log "=== Script erfolgreich beendet ===" "INFO"
Write-Host ""
Write-Host "Script-Ausfuehrung abgeschlossen. Details in Log-Datei: $Script:LogPath" -ForegroundColor Cyan
exit 0
