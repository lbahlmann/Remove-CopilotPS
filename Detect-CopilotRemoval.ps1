<#
.SYNOPSIS
    Detection-Script fuer SCCM/Intune Deployment
.DESCRIPTION
    Dieses Script dient als Detection Method fuer SCCM/ConfigMgr und Microsoft Intune.

    Pruefungen (4):
    1. App-Pakete (installiert & provisioniert)
    2. Registry: TurnOffWindowsCopilot = 1
    3. Kontextmenue: Shell Extension GUID blockiert
    4. Hosts-Datei: copilot.microsoft.com blockiert

    Exit Codes:
    - 0 = Copilot NICHT gefunden (Removal erfolgreich) - COMPLIANT
    - 1 = Copilot gefunden (Removal erforderlich) - NON-COMPLIANT

    Fuer SCCM/Intune Konfiguration:
    - Detection Method: Script
    - Script Type: PowerShell
    - Run script as 32-bit: No
    - Run script using logged on credentials: No
.EXAMPLE
    .\Detect-CopilotRemoval.ps1
    Fuehrt Detection aus und gibt Exit-Code zurueck
.EXAMPLE
    .\Detect-CopilotRemoval.ps1 -Verbose
    Fuehrt Detection mit Debug-Output aus
.NOTES
    Dieses Script gibt keine Console-Ausgabe aus (ausser im Debug-Modus).
    Alle Ausgaben erfolgen ueber Exit-Codes fuer SCCM/Intune.
.AUTHOR
    Lars Bahlmann / badata GmbH - IT Systemhaus in Bremen / www.badata.de
.VERSION
    1.1 - November 2025 (Added Hosts File Check)
#>

param(
    [switch]$Verbose
)

# ========================================
# DETECTION-LOGIK
# ========================================

# Verbose-Modus aktivieren (fuer Debugging)
$DebugMode = $Verbose

function Write-DebugLog {
    param([string]$Message)
    if ($DebugMode) {
        Write-Host "[DEBUG] $Message"
    }
}

Write-DebugLog "Starte Copilot-Erkennung..."

# ========================================
# PRUEFUNG 1: App-Pakete
# ========================================
Write-DebugLog "Pruefe App-Pakete..."

$CopilotPackages = @(
    "Microsoft.Copilot",
    "Microsoft.Windows.Ai.Copilot.Provider",
    "MicrosoftWindows.Client.WebExperience",
    "Microsoft.WindowsCopilot",
    "Microsoft.Windows.Copilot"
)

$PackagesFound = $false

foreach ($Package in $CopilotPackages) {
    $Installed = Get-AppxPackage -AllUsers -Name "*$Package*" -ErrorAction SilentlyContinue
    if ($Installed) {
        Write-DebugLog "GEFUNDEN: Paket $($Installed.Name)"
        $PackagesFound = $true
        break
    }
}

# Provisionierte Pakete pruefen
if (-not $PackagesFound) {
    $Provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -like "*Copilot*" }
    if ($Provisioned) {
        Write-DebugLog "GEFUNDEN: Provisioniertes Paket $($Provisioned.DisplayName)"
        $PackagesFound = $true
    }
}

# Wenn Copilot-Pakete gefunden wurden, ist das System NON-COMPLIANT
if ($PackagesFound) {
    Write-DebugLog "Erkennungs-Ergebnis: NON-COMPLIANT (Copilot-Pakete gefunden)"
    exit 1  # NON-COMPLIANT
}

# ========================================
# PRUEFUNG 2: Registry-Blockierung
# ========================================
Write-DebugLog "Pruefe Registry-Einstellungen..."

$RegistryChecks = @(
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name="TurnOffWindowsCopilot"; Expected=1}
)

foreach ($Check in $RegistryChecks) {
    try {
        $Value = Get-ItemProperty -Path $Check.Path -Name $Check.Name -ErrorAction SilentlyContinue
        if ($null -eq $Value -or $Value.($Check.Name) -ne $Check.Expected) {
            Write-DebugLog "Erkennungs-Ergebnis: NON-COMPLIANT (Registry nicht konfiguriert)"
            exit 1  # NON-COMPLIANT
        }
    } catch {
        Write-DebugLog "Erkennungs-Ergebnis: NON-COMPLIANT (Registry-Schluessel fehlt)"
        exit 1  # NON-COMPLIANT
    }
}

# ========================================
# PRUEFUNG 3: Kontextmenue-Blockierung
# ========================================
Write-DebugLog "Pruefe Kontextmenue-Blockierung..."

$BlockedPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked"
$CopilotGUID = "{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}"

try {
    $Blocked = Get-ItemProperty -Path $BlockedPath -Name $CopilotGUID -ErrorAction SilentlyContinue
    if (-not $Blocked) {
        Write-DebugLog "Erkennungs-Ergebnis: NON-COMPLIANT (Kontextmenue nicht blockiert)"
        exit 1  # NON-COMPLIANT
    }
} catch {
    Write-DebugLog "Erkennungs-Ergebnis: NON-COMPLIANT (Kontextmenue-Blockierung nicht konfiguriert)"
    exit 1  # NON-COMPLIANT
}

# ========================================
# PRUEFUNG 4: Hosts-Datei
# ========================================
Write-DebugLog "Pruefe Hosts-Datei..."

$HostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
try {
    $HostsContent = Get-Content $HostsFile -ErrorAction Stop
    $HostsConfigured = $HostsContent -match 'copilot\.microsoft\.com'

    if (-not $HostsConfigured) {
        Write-DebugLog "Erkennungs-Ergebnis: NON-COMPLIANT (Hosts-Datei nicht konfiguriert)"
        exit 1  # NON-COMPLIANT
    }

    Write-DebugLog "Hosts-Datei konfiguriert - copilot.microsoft.com blockiert"
} catch {
    Write-DebugLog "Erkennungs-Ergebnis: NON-COMPLIANT (Hosts-Datei nicht zugreifbar)"
    exit 1  # NON-COMPLIANT
}

# ========================================
# ALLE PRUEFUNGEN BESTANDEN
# ========================================
Write-DebugLog "Erkennungs-Ergebnis: COMPLIANT (Copilot entfernt und blockiert)"
exit 0  # COMPLIANT
