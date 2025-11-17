<#
.SYNOPSIS
    Detection-Script für SCCM/Intune Deployment
.DESCRIPTION
    Dieses Script dient als Detection Method für SCCM/ConfigMgr und Microsoft Intune.

    Exit Codes:
    - 0 = Copilot NICHT gefunden (Removal erfolgreich) - COMPLIANT
    - 1 = Copilot gefunden (Removal erforderlich) - NON-COMPLIANT

    Für SCCM/Intune Konfiguration:
    - Detection Method: Script
    - Script Type: PowerShell
    - Run script as 32-bit: No
    - Run script using logged on credentials: No
.EXAMPLE
    .\Detect-CopilotRemoval.ps1
    Führt Detection aus und gibt Exit-Code zurück
.NOTES
    Dieses Script gibt keine Console-Ausgabe aus (außer im Debug-Modus).
    Alle Ausgaben erfolgen über Exit-Codes für SCCM/Intune.
.AUTHOR
    Lars Bahlmann / badata GmbH - IT Systemhaus in Bremen / www.badata.de
.VERSION
    1.0 - November 2025
#>

param(
    [switch]$Verbose
)

# ========================================
# DETECTION-LOGIK
# ========================================

# Verbose-Modus aktivieren (für Debugging)
$DebugMode = $Verbose

function Write-DebugLog {
    param([string]$Message)
    if ($DebugMode) {
        Write-Host "[DEBUG] $Message"
    }
}

Write-DebugLog "Starting Copilot Detection..."

# ========================================
# PRÜFUNG 1: App-Pakete
# ========================================
Write-DebugLog "Checking App Packages..."

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
        Write-DebugLog "FOUND: Package $($Installed.Name)"
        $PackagesFound = $true
        break
    }
}

# Provisionierte Pakete prüfen
if (-not $PackagesFound) {
    $Provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -like "*Copilot*" }
    if ($Provisioned) {
        Write-DebugLog "FOUND: Provisioned Package $($Provisioned.DisplayName)"
        $PackagesFound = $true
    }
}

# Wenn Copilot-Pakete gefunden wurden, ist das System NON-COMPLIANT
if ($PackagesFound) {
    Write-DebugLog "Detection Result: NON-COMPLIANT (Copilot packages found)"
    exit 1  # NON-COMPLIANT
}

# ========================================
# PRÜFUNG 2: Registry-Blockierung
# ========================================
Write-DebugLog "Checking Registry Settings..."

$RegistryChecks = @(
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name="TurnOffWindowsCopilot"; Expected=1}
)

foreach ($Check in $RegistryChecks) {
    try {
        $Value = Get-ItemProperty -Path $Check.Path -Name $Check.Name -ErrorAction SilentlyContinue
        if ($null -eq $Value -or $Value.($Check.Name) -ne $Check.Expected) {
            Write-DebugLog "Detection Result: NON-COMPLIANT (Registry not configured)"
            exit 1  # NON-COMPLIANT
        }
    } catch {
        Write-DebugLog "Detection Result: NON-COMPLIANT (Registry key missing)"
        exit 1  # NON-COMPLIANT
    }
}

# ========================================
# PRÜFUNG 3: Kontextmenü-Blockierung
# ========================================
Write-DebugLog "Checking Context Menu Block..."

$BlockedPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked"
$CopilotGUID = "{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}"

try {
    $Blocked = Get-ItemProperty -Path $BlockedPath -Name $CopilotGUID -ErrorAction SilentlyContinue
    if (-not $Blocked) {
        Write-DebugLog "Detection Result: NON-COMPLIANT (Context menu not blocked)"
        exit 1  # NON-COMPLIANT
    }
} catch {
    Write-DebugLog "Detection Result: NON-COMPLIANT (Context menu block not configured)"
    exit 1  # NON-COMPLIANT
}

# ========================================
# ALLE PRÜFUNGEN BESTANDEN
# ========================================
Write-DebugLog "Detection Result: COMPLIANT (Copilot removed and blocked)"
exit 0  # COMPLIANT
