#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Erstellt WDAC (Windows Defender Application Control) Policy zur Copilot-Blockierung
.DESCRIPTION
    Dieses Script erstellt eine Code Integrity Policy auf Kernel-Ebene,
    um Microsoft Copilot zu blockieren. WDAC ist restriktiver als AppLocker
    und bietet Schutz auf tieferer Systemebene.

    ACHTUNG: WDAC ist sehr restriktiv und erfordert sorgfaeltige Tests!
    Nur fuer Enterprise-Umgebungen mit IT-Expertise empfohlen.

    Das Script:
    1. Erstellt eine WDAC-Policy-XML
    2. Blockiert Copilot basierend auf Package Family Name
    3. Konvertiert XML zu binaerer Policy
    4. Deployed die Policy (optional)

.PARAMETER PolicyPath
    Pfad zur Policy-XML (Standard: C:\Temp\WDACCopilotBlock.xml)
.PARAMETER Deploy
    Deployed die Policy nach Erstellung
.PARAMETER AuditOnly
    Erstellt Policy im Audit-Modus (nur Logging, kein Blocking)
.EXAMPLE
    .\Enable-WDACCopilotBlock.ps1
    Erstellt WDAC Policy ohne Deployment
.EXAMPLE
    .\Enable-WDACCopilotBlock.ps1 -Deploy
    Erstellt und deployed WDAC Policy
.EXAMPLE
    .\Enable-WDACCopilotBlock.ps1 -AuditOnly -Deploy
    Erstellt Audit-Policy (empfohlen fuer Tests!)
.AUTHOR
    Lars Bahlmann / badata GmbH - IT Systemhaus in Bremen / www.badata.de
.VERSION
    1.0 - November 2025
.NOTES
    - Erfordert Windows 10/11 Enterprise oder Windows Server
    - Erfordert Administratorrechte
    - WDAC Policies erfordern Neustart
    - Im Audit-Modus werden Ereignisse nur geloggt, nicht geblockt
    - WICHTIG: Teste in VM/Testumgebung zuerst!
#>

param(
    [string]$PolicyPath = "C:\Temp\WDACCopilotBlock.xml",
    [switch]$Deploy,
    [switch]$AuditOnly
)

# ========================================
# FUNKTIONEN
# ========================================
function Write-Log {
    param(
        [string]$Message,
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
}

function Test-WDACSupport {
    Write-Log "Pruefe WDAC-Unterstuetzung..." -Type Info

    # Pruefe Windows-Edition
    $Edition = (Get-WindowsEdition -Online).Edition
    if ($Edition -notmatch "Enterprise|Education|Server") {
        Write-Log "WARNUNG: WDAC wird typischerweise nur auf Enterprise/Education/Server unterstuetzt" -Type Warning
        Write-Log "Aktuelle Edition: $Edition" -Type Warning
        $Continue = Read-Host "Trotzdem fortfahren? (J/N)"
        if ($Continue -ne "J" -and $Continue -ne "j") {
            Write-Log "Abgebrochen durch Benutzer" -Type Info
            exit 0
        }
    }

    # Pruefe ob ConfigCI-Modul verfuegbar ist
    $ConfigCI = Get-Command -Name New-CIPolicy -ErrorAction SilentlyContinue
    if (-not $ConfigCI) {
        Write-Log "FEHLER: ConfigCI PowerShell-Modul nicht verfuegbar!" -Type Error
        Write-Log "WDAC wird auf diesem System nicht unterstuetzt" -Type Error
        exit 1
    }

    Write-Log "WDAC wird unterstuetzt" -Type Success
    return $true
}

function Get-CopilotPackageInfo {
    Write-Log "Sammle Copilot Package-Informationen..." -Type Info

    $CopilotPackages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*Copilot*" }

    if ($CopilotPackages) {
        Write-Log "Gefundene Copilot-Pakete:" -Type Info
        foreach ($Pkg in $CopilotPackages) {
            Write-Log "  - $($Pkg.Name)" -Type Info
            Write-Log "    Package Family Name: $($Pkg.PackageFamilyName)" -Type Info
            Write-Log "    Publisher: $($Pkg.Publisher)" -Type Info
        }
        return $CopilotPackages
    } else {
        Write-Log "HINWEIS: Keine Copilot-Pakete installiert (gut!)" -Type Success
        Write-Log "Policy wird trotzdem erstellt zur Praevention" -Type Info
        return $null
    }
}

function New-WDACCopilotPolicy {
    param(
        [string]$OutputPath,
        [bool]$AuditMode
    )

    Write-Log "Erstelle WDAC Policy..." -Type Info

    # Erstelle Temp-Verzeichnis fuer Policy-Erstellung
    $TempDir = Join-Path $env:TEMP "WDACCopilot_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null

    try {
        # Basis-Policy erstellen (DefaultWindows_Audit)
        $BasePolicyPath = Join-Path $TempDir "BasePolicy.xml"

        # Erstelle eine neue, leere Policy
        # Level 8 = FilePublisher + Hash
        New-CIPolicy -FilePath $BasePolicyPath `
                     -Level FilePublisher `
                     -UserPEs `
                     -Fallback Hash `
                     -ScanPath "C:\Windows\System32" `
                     -NoShadowCopy | Out-Null

        Write-Log "Basis-Policy erstellt" -Type Success

        # Lade Policy als XML
        [xml]$PolicyXML = Get-Content $BasePolicyPath

        # Policy-Metadaten aktualisieren
        $PolicyXML.SiPolicy.PolicyID = [guid]::NewGuid().ToString("B").ToUpper()
        $PolicyXML.SiPolicy.SetAttribute("PolicyType", "Base Policy")
        $PolicyXML.SiPolicy.SetAttribute("PolicyName", "Block Microsoft Copilot")

        # Erstelle FileRules-Knoten falls nicht vorhanden
        if (-not $PolicyXML.SiPolicy.FileRules) {
            $FileRulesNode = $PolicyXML.CreateElement("FileRules", $PolicyXML.SiPolicy.NamespaceURI)
            $PolicyXML.SiPolicy.AppendChild($FileRulesNode) | Out-Null
        }

        # Deny-Regel 1: Microsoft.Copilot
        $DenyRule1 = $PolicyXML.CreateElement("Deny", $PolicyXML.SiPolicy.NamespaceURI)
        $DenyRule1.SetAttribute("ID", "ID_DENY_COPILOT_1")
        $DenyRule1.SetAttribute("FriendlyName", "Block Microsoft Copilot")
        $DenyRule1.SetAttribute("FileName", "Microsoft.Copilot*.exe")
        $PolicyXML.SiPolicy.FileRules.AppendChild($DenyRule1) | Out-Null

        # Deny-Regel 2: Copilot Provider
        $DenyRule2 = $PolicyXML.CreateElement("Deny", $PolicyXML.SiPolicy.NamespaceURI)
        $DenyRule2.SetAttribute("ID", "ID_DENY_COPILOT_2")
        $DenyRule2.SetAttribute("FriendlyName", "Block Copilot Provider")
        $DenyRule2.SetAttribute("FileName", "Microsoft.Windows.Ai.Copilot.Provider*.exe")
        $PolicyXML.SiPolicy.FileRules.AppendChild($DenyRule2) | Out-Null

        Write-Log "Deny-Regeln zur Policy hinzugefuegt" -Type Success

        # Fuege Policy-Optionen hinzu
        if ($AuditMode) {
            Write-Log "Erstelle Policy im AUDIT-MODUS (nur Logging)" -Type Warning

            # Option 3 = Enabled:Audit Mode
            $AuditOption = $PolicyXML.CreateElement("Option")
            $AuditOption.InnerText = "Enabled:Audit Mode"
            $PolicyXML.SiPolicy.Rules.AppendChild($AuditOption) | Out-Null
        } else {
            Write-Log "Erstelle Policy im ENFORCEMENT-MODUS (Blocking aktiv)" -Type Warning
        }

        # Speichere modifizierte Policy
        $PolicyXML.Save($OutputPath)

        Write-Log "WDAC Policy erstellt: $OutputPath" -Type Success

        # Cleanup
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue

        return $true

    } catch {
        Write-Log "Fehler beim Erstellen der WDAC Policy: $($_.Exception.Message)" -Type Error
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Convert-PolicyToBinary {
    param(
        [string]$XMLPath
    )

    Write-Log "Konvertiere Policy zu binaerem Format..." -Type Info

    $BinaryPath = $XMLPath -replace "\.xml$", ".bin"

    try {
        ConvertFrom-CIPolicy -XmlFilePath $XMLPath -BinaryFilePath $BinaryPath

        if (Test-Path $BinaryPath) {
            Write-Log "Binaere Policy erstellt: $BinaryPath" -Type Success
            return $BinaryPath
        } else {
            Write-Log "FEHLER: Binaere Policy konnte nicht erstellt werden" -Type Error
            return $null
        }
    } catch {
        Write-Log "Fehler bei Policy-Konvertierung: $($_.Exception.Message)" -Type Error
        return $null
    }
}

function Deploy-WDACPolicy {
    param(
        [string]$BinaryPath
    )

    Write-Log "" -Type Info
    Write-Log "========================================" -Type Warning
    Write-Log "WDAC POLICY DEPLOYMENT" -Type Warning
    Write-Log "========================================" -Type Warning
    Write-Log "ACHTUNG: Das Deployment einer WDAC Policy ist ein kritischer Vorgang!" -Type Warning
    Write-Log "         Falsch konfigurierte Policies koennen Systeminstabilitaet verursachen!" -Type Warning
    Write-Log "" -Type Info

    $Confirm = Read-Host "Moechten Sie die Policy wirklich deployen? (J/N)"
    if ($Confirm -ne "J" -and $Confirm -ne "j") {
        Write-Log "Deployment abgebrochen" -Type Info
        return $false
    }

    Write-Log "Deploye WDAC Policy..." -Type Info

    try {
        # Policy GUID erstellen
        $PolicyGUID = [guid]::NewGuid().ToString("B").ToUpper()
        $DeployPath = "C:\Windows\System32\CodeIntegrity\CiPolicies\Active"

        # Stelle sicher, dass Verzeichnis existiert
        if (-not (Test-Path $DeployPath)) {
            New-Item -Path $DeployPath -ItemType Directory -Force | Out-Null
        }

        # Kopiere Policy mit GUID-Namen
        $DeployFile = Join-Path $DeployPath "$PolicyGUID.cip"
        Copy-Item -Path $BinaryPath -Destination $DeployFile -Force

        Write-Log "Policy deployed: $DeployFile" -Type Success
        Write-Log "" -Type Info
        Write-Log "========================================" -Type Warning
        Write-Log "NEUSTART ERFORDERLICH" -Type Warning
        Write-Log "========================================" -Type Warning
        Write-Log "Die WDAC Policy wird erst nach einem Neustart aktiv!" -Type Warning

        $Restart = Read-Host "Jetzt neu starten? (J/N)"
        if ($Restart -eq "J" -or $Restart -eq "j") {
            Write-Log "Computer wird in 10 Sekunden neu gestartet..." -Type Warning
            Start-Sleep -Seconds 10
            Restart-Computer -Force
        }

        return $true

    } catch {
        Write-Log "Fehler beim Deployment: $($_.Exception.Message)" -Type Error
        return $false
    }
}

# ========================================
# HAUPTPROGRAMM
# ========================================
Write-Log "======================================" -Type Info
Write-Log "WDAC Copilot-Blockierung v1.0" -Type Info
Write-Log "======================================" -Type Info
Write-Log "" -Type Info

# Pruefe Admin-Rechte
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "FEHLER: Script erfordert Administratorrechte!" -Type Error
    exit 1
}

# Pruefe WDAC-Unterstuetzung
if (-not (Test-WDACSupport)) {
    exit 1
}

# Sammle Copilot-Informationen
Get-CopilotPackageInfo

# Erstelle Policy
$PolicyCreated = New-WDACCopilotPolicy -OutputPath $PolicyPath -AuditMode $AuditOnly

if (-not $PolicyCreated) {
    Write-Log "Policy-Erstellung fehlgeschlagen!" -Type Error
    exit 1
}

# Konvertiere zu Binary
$BinaryPath = Convert-PolicyToBinary -XMLPath $PolicyPath

if (-not $BinaryPath) {
    Write-Log "Policy-Konvertierung fehlgeschlagen!" -Type Error
    exit 1
}

Write-Log "" -Type Info
Write-Log "======================================" -Type Success
Write-Log "WDAC Policy erfolgreich erstellt!" -Type Success
Write-Log "======================================" -Type Success
Write-Log "XML Policy:    $PolicyPath" -Type Info
Write-Log "Binary Policy: $BinaryPath" -Type Info
Write-Log "Modus:         $(if($AuditOnly){'AUDIT (nur Logging)'}else{'ENFORCEMENT (Blocking)'})" -Type Info

# Deployment (optional)
if ($Deploy) {
    Write-Log "" -Type Info
    Deploy-WDACPolicy -BinaryPath $BinaryPath
} else {
    Write-Log "" -Type Info
    Write-Log "Policy wurde NICHT deployed (verwenden Sie -Deploy Parameter)" -Type Info
    Write-Log "" -Type Info
    Write-Log "Manuelles Deployment:" -Type Info
    Write-Log "1. Policy in Testumgebung ausfuehrlich testen!" -Type Warning
    Write-Log "2. Policy deployen:" -Type Info
    Write-Log "   Copy-Item '$BinaryPath' 'C:\Windows\System32\CodeIntegrity\CiPolicies\Active\{GUID}.cip'" -Type Info
    Write-Log "3. System neu starten" -Type Info
}

Write-Log "" -Type Info
Write-Log "WICHTIGE HINWEISE:" -Type Warning
Write-Log "- Teste die Policy in einer VM oder Testumgebung zuerst!" -Type Warning
Write-Log "- Im Audit-Modus werden Ereignisse im Event Log angezeigt" -Type Info
Write-Log "- Event Viewer: Applications and Services Logs > Microsoft > Windows > CodeIntegrity > Operational" -Type Info
Write-Log "- Zum Entfernen der Policy: Datei aus CiPolicies\Active\ loeschen + Neustart" -Type Info

Write-Log "" -Type Info
Write-Log "Script beendet" -Type Success
exit 0
