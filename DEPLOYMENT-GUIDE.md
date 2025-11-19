# Copilot Removal - Deployment Guide v2.1.3

Vollständige Anleitung zum Deployment des Microsoft Copilot Removal Toolkit in Unternehmensumgebungen.

**Version:** 2.1.3 (November 2025)
**Status:** ✅ Production Ready

---

## 📋 Übersicht

Dieses Toolkit entfernt Microsoft Copilot vollständig und verhindert Neuinstallation durch:
- **Phase 1:** App-Paket Entfernung (installiert + provisioniert)
- **Phase 1b:** Deprovisioned Registry Keys ✨ NEU v2.1.3
- **Phase 2:** 33 Registry-Einstellungen (inkl. Microsoft 365 Copilot)
- **Phase 3:** Kontextmenü-Blockierung
- **Phase 4:** AppLocker-Regeln (5 Rules: Publisher + Path) ✨ NEU v2.1.3
- **Phase 4b:** Protocol Handler Blockierung ✨ NEU v2.1.3
- **Phase 4c:** Store Auto-Update Blockierung ✨ NEU v2.1.3
- **Phase 5:** 6 DNS-Domain-Blockierungen
- **Phase 6:** Scheduled Task Deaktivierung
- **Phase 7:** Firewall-Regeln

---

## 🆕 Neu in v2.1.3

✅ **Provisioned Package Removal** - Verhindert Installation für neue Windows-User
✅ **Deprovisioned Registry Keys** - 5 Package Family Names (Feature Update Reinstallation Prevention)
✅ **Protocol Handler Blockierung** - ms-copilot://, microsoft-edge-holographic://, ms-windows-ai-copilot://
✅ **Store Auto-Update Blockierung** - 5 Copilot-Pakete blockiert (Store bleibt funktional!)
✅ **AppLocker Enhanced** - 5 Deny Rules (3x FilePublisher + 2x FilePath)
✅ **Hotfix 1:** HKCR PSDrive creation (verhindert "Laufwerk nicht gefunden" Fehler)

**Statistik:**
- +250 Zeilen Code
- 3 neue Funktionen
- 3 neue Phasen (1b, 4b, 4c)
- 5 Reinstallations-Vektoren blockiert

## Neu in v2.1.2

✅ **Microsoft 365 Copilot Blockierung** - Vollständig in Word, Excel, PowerPoint, Outlook, OneNote
✅ **13 neue Registry-Keys** - Per-Application Controls
✅ **Enhanced Monitoring** - Test-Script prüft M365 Copilot

## Neu in v2.1.1

✅ **Unattended-Modus** - Vollautomatisch für GPO/Intune/SCCM
✅ **NoGPUpdate-Parameter** - Verhindert Domain-GPO-Konflikte
✅ **UseTemp-Parameter** - RDS/Terminal Server Support
✅ **BackupDir-Parameter** - Custom Backup-Pfade
✅ **Performance** - Registry-Operations 75% schneller
✅ **Bugfixes** - Alle kritischen Fehler behoben

---

## 🚀 Schnellstart

### Testlauf (IMMER ZUERST!)

```powershell
.\Remove-CopilotComplete.ps1 -LogOnly
```

### Produktiv-Ausführung

```powershell
.\Remove-CopilotComplete.ps1 -Unattended -NoGPUpdate
```

---

## 1️⃣ Remove-CopilotComplete.ps1

**Hauptscript zur vollständigen Copilot-Entfernung**

### Parameter

```powershell
Remove-CopilotComplete.ps1
    [-LogOnly]           # Testlauf ohne Änderungen
    [-NoRestart]         # Kein Explorer-Neustart
    [-SkipBackup]        # Kein Backup (nicht empfohlen!)
    [-Force]             # Keine Bestätigungsdialoge
    [-Unattended]        # Vollautomatisch (impliziert -Force -NoRestart)
    [-UseTemp]           # C:\Temp\CopilotRemoval\$env:USERNAME (RDS)
    [-BackupDir <path>]  # Custom Backup-Pfad
    [-NoGPUpdate]        # Kein gpupdate /force
```

### 10-Phasen-Strategie (v2.1.3)

1. **App-Paket Entfernung** - AppX-Pakete (installiert + provisioniert)
2. **Deprovisioned Keys** ✨ NEU - Feature Update Reinstallation Prevention
3. **Registry-Konfiguration** - 33 Einstellungen (Windows, Edge, Office, M365)
4. **Kontextmenü-Blockierung** - Shell Extension GUID
5. **AppLocker-Regeln** ✨ ENHANCED - 5 Deny Rules (Publisher + Path)
6. **Protocol Handler** ✨ NEU - ms-copilot:// blockiert
7. **Store Auto-Update** ✨ NEU - Copilot-Pakete blockiert (Store funktional!)
8. **DNS-Blockierung** - 6 Copilot-Domains in hosts-Datei
9. **Scheduled Tasks** - AI-Tasks deaktivieren
10. **Firewall-Regeln** - Netzwerk-Blockierung

### Deployment-Szenarien

#### Szenario 1: Einzelne Workstation

```powershell
# Test
.\Remove-CopilotComplete.ps1 -LogOnly

# Produktiv
.\Remove-CopilotComplete.ps1
```

#### Szenario 2: Domain-Computer

```powershell
# Mit NoGPUpdate (verhindert GPO-Überschreibung)
.\Remove-CopilotComplete.ps1 -Unattended -NoGPUpdate
```

#### Szenario 3: RDS/Terminal Server

```powershell
# User-spezifische Pfade
.\Remove-CopilotComplete.ps1 -UseTemp -Unattended -NoGPUpdate
```

#### Szenario 4: Backup auf Netzlaufwerk

```powershell
.\Remove-CopilotComplete.ps1 -Unattended -BackupDir "\\server\backup\copilot"
```

### Backup-Struktur

```
$env:LOCALAPPDATA\CopilotRemoval\Backup_YYYYMMDD_HHMMSS\
├── Registry_*.reg              # Registry-Backups
├── hosts.backup                # Hosts-Datei Backup
├── Report_YYYYMMDD_HHMMSS.json # Execution Report
└── Log_YYYYMMDD_HHMMSS.txt     # Detailliertes Log
```

### Rollback

**Registry wiederherstellen:**
1. Backup-Verzeichnis öffnen
2. `.reg` Datei doppelklicken
3. Import bestätigen
4. Neustart

**Hosts-Datei wiederherstellen:**
```powershell
Copy-Item "$env:LOCALAPPDATA\CopilotRemoval\Backup_*\hosts.backup" `
          "$env:SystemRoot\System32\drivers\etc\hosts" -Force
```

### Reinstallation Prevention (v2.1.3)

✅ **5 Schutz-Ebenen gegen Neuinstallation:**

1. **Provisioned Package Removal** - Entfernt AppX Provisioned Packages (Get-AppxProvisionedPackage)
2. **Deprovisioned Registry Keys** - HKLM:\\...\\Appx\\AppxAllUserStore\\Deprovisioned\\{PackageFamilyName}
3. **AppLocker Rules** - Application-Level Enforcement (5 Rules: 3x Publisher, 2x Path)
4. **Protocol Handler Blocking** - HKCR Registry Keys (ms-copilot, microsoft-edge-holographic, ms-windows-ai-copilot)
5. **Store Auto-Update Blocking** - HKLM:\\...\\Appx\\AppxAllUserStore\\BlockedPackages + Optional Features

---

## 2️⃣ Deployment via GPO

### Vorteile
- ✅ Einfache Verwaltung
- ✅ Automatische Anwendung bei Domänen-PCs
- ✅ Keine zusätzliche Infrastruktur

### Einrichtung

1. **Script auf Netzlaufwerk kopieren**
   ```
   \\domain.local\NETLOGON\Scripts\CopilotRemoval\Remove-CopilotComplete.ps1
   ```

2. **GPO erstellen**
   - `Computer Configuration` → `Policies` → `Windows Settings` → `Scripts` → `Startup`

3. **PowerShell Script hinzufügen**
   - Script Name: `\\domain.local\NETLOGON\Scripts\CopilotRemoval\Remove-CopilotComplete.ps1`
   - Script Parameters: `-Unattended -NoGPUpdate`

4. **GPO verknüpfen**
   - Ziel-OU auswählen
   - Sicherheitsfilterung konfigurieren

5. **Optional: Monitoring einrichten**
   - Scheduled Task für `Test-CopilotPresence.ps1` per GPO verteilen

### Empfohlene Parameter

```
-Unattended -NoGPUpdate
```

⚠️ **Wichtig:** `-NoGPUpdate` verhindert, dass `gpupdate /force` die lokalen Registry-Änderungen mit Domain-GPOs überschreibt!

### GPO-Alternative: Group Policy Settings

📖 **Für manuelle GPO-Konfiguration ohne Script:** Siehe <a href="GPO-DEPLOYMENT-GUIDE.md" target="_blank">GPO-DEPLOYMENT-GUIDE.md</a>

Inhalt:
- ✅ AppLocker Policy (Microsoft-empfohlen)
- ✅ Registry-basierte Einstellungen
- ✅ M365 Copilot ADMX Templates
- ✅ Intune/MDM Configuration Profiles

---

## 3️⃣ Deployment via Microsoft Intune

### Vorteile
- ✅ Cloud-basiert
- ✅ Umfassendes Reporting
- ✅ Deployment-Status pro Gerät

### App erstellen

1. **IntuneWinAppUtil herunterladen**
   ```powershell
   # https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool
   ```

2. **.intunewin Paket erstellen**
   ```powershell
   .\IntuneWinAppUtil.exe `
       -c "C:\Source\CopilotRemoval" `
       -s "Remove-CopilotComplete.ps1" `
       -o "C:\Output"
   ```

3. **Intune Portal** → Apps → All apps → Add
   - App type: `Windows app (Win32)`

4. **App information**
   - Name: `Remove Microsoft Copilot v2.1.3`
   - Description: `Vollständige Entfernung und Blockierung von Microsoft Copilot - Reinstallation Prevention`
   - Publisher: `Your Organization`

5. **Program**

   **Install command:**
   ```
   powershell.exe -ExecutionPolicy Bypass -File "Remove-CopilotComplete.ps1" -Unattended
   ```

   **Uninstall command:** (leer lassen)

   **Install behavior:** `System`

   **Device restart behavior:** `Determine behavior based on return codes`

6. **Requirements**
   - Operating system architecture: `64-bit`
   - Minimum operating system: `Windows 10 1809`

7. **Detection rules**
   - Rule format: `Use a custom detection script`
   - Script file: `Detect-CopilotRemoval.ps1`
   - Run script as 32-bit: `No`

8. **Return codes**
   - 0 = Success
   - 1 = Failed

9. **Assignment**
   - Required: `All Devices` oder spezifische Gruppe
   - End user notifications: `Show all toast notifications`

### Intune Alternative: Configuration Profiles

📖 **Für Cloud-basierte Policy-Konfiguration:** Siehe <a href="GPO-DEPLOYMENT-GUIDE.md#intunemdm-konfiguration" target="_blank">GPO-DEPLOYMENT-GUIDE.md</a>

Inhalt:
- ✅ Settings Catalog (WindowsAI CSP)
- ✅ Cloud Policy Service (M365 Copilot)
- ✅ Custom OMA-URI

---

## 4️⃣ Deployment via SCCM/ConfigMgr

### Vorteile
- ✅ On-Premises Kontrolle
- ✅ Detailliertes Reporting
- ✅ Phased Rollout möglich

### Application erstellen

1. **General Information**
   - Name: `Remove Microsoft Copilot`
   - Publisher: `Your Organization`
   - Software Version: `2.1.3`

2. **Deployment Type** → Script Installer

   **Content Location:**
   ```
   \\server\share\CopilotRemoval\
   ```

   **Installation Program:**
   ```
   powershell.exe -ExecutionPolicy Bypass -File "Remove-CopilotComplete.ps1" -Unattended -NoGPUpdate
   ```

3. **Detection Method** → Use a custom script
   - Script Type: `PowerShell`
   - Script file: `Detect-CopilotRemoval.ps1`
   - Run script as 32-bit: `No`
   - Run script using logged on credentials: `No`

4. **User Experience**
   - Installation behavior: `Install for system`
   - Logon requirement: `Whether or not a user is logged on`
   - Installation program visibility: `Hidden`
   - Maximum allowed run time: `60 minutes`

5. **Requirements**
   - Operating System: `Windows 10` oder `Windows 11`
   - Minimum OS version: `Windows 10 1809`

6. **Deployment**
   - Purpose: `Required`
   - Deadline: `Nach Bedarf`
   - Rerun behavior: `Rerun if failed previous attempt`

---

## 5️⃣ Test-CopilotPresence.ps1 (Monitoring)

**Regelmäßige Überprüfung ob Copilot wieder erschienen ist**

### Parameter

```powershell
Test-CopilotPresence.ps1
    [-EmailAlert <email>]
    [-SMTPServer <server>]
    [-CreateScheduledTask]
    [-LogPath <path>]
    [-UseTemp]
```

### Neue Überprüfungen (v2.1.3)

✅ **Deprovisioned Registry Keys** - 5 Package Family Names
✅ **Protocol Handler** - 3 Handler (ms-copilot, microsoft-edge-holographic, ms-windows-ai-copilot)
✅ **Store BlockedPackages** - 5 Copilot-Pakete
✅ **Optional Features** - Copilot Feature blockiert

### Scheduled Task erstellen

```powershell
# Monatlicher Task (1. des Monats, 08:00 Uhr)
.\Test-CopilotPresence.ps1 -CreateScheduledTask
```

### Exit Codes

- **0** = Sauber (kein Copilot gefunden)
- **1** = Copilot gefunden (Aktion erforderlich)
- **2** = Blockierungen unvollständig

### Deployment via GPO

**Scheduled Task per GPO verteilen:**
1. Task-XML erstellen
2. `Computer Configuration` → `Preferences` → `Control Panel Settings` → `Scheduled Tasks`
3. Action: `Replace`
4. Task-XML importieren

---

## 6️⃣ Detect-CopilotRemoval.ps1

**SCCM/Intune Detection Script**

### Exit Codes

- **0** = COMPLIANT (Copilot nicht gefunden)
- **1** = NON-COMPLIANT (Copilot gefunden oder Blockierungen fehlen)

### Prüfungen (v2.1.3)

1. App-Pakete (installiert & provisioniert)
2. Registry: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot\TurnOffWindowsCopilot`
3. Kontextmenü: Shell Extension GUID `{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}` blockiert
4. ✨ **Deprovisioned Keys** - 5 Package Family Names
5. ✨ **Store BlockedPackages** - 5 Copilot-Pakete

---

## 7️⃣ Enable-WDACCopilotBlock.ps1

**WDAC Kernel-Ebene Blockierung (Optional)**

⚠️ **Nur für Enterprise mit umfangreichen Tests!**

### Parameter

```powershell
Enable-WDACCopilotBlock.ps1
    [-PolicyPath <path>]
    [-Deploy]
    [-AuditOnly]
```

### Beispiele

```powershell
# Test: Audit-Modus
.\Enable-WDACCopilotBlock.ps1 -AuditOnly -Deploy

# Produktiv
.\Enable-WDACCopilotBlock.ps1 -Deploy
```

### WDAC Removal

```powershell
# Policy entfernen
Remove-Item "C:\Windows\System32\CodeIntegrity\CiPolicies\Active\*.cip"
# Neustart
Restart-Computer
```

---

## 8️⃣ Best Practices

### Vor dem Rollout

1. ✅ **Testumgebung**
   - Windows 10/11 (verschiedene Builds)
   - Home/Pro/Enterprise
   - Mit/ohne Office
   - Domain vs. Standalone

2. ✅ **Backup-Strategie**
   - Systemwiederherstellungspunkt
   - Backup auf Netzlaufwerk (`-BackupDir`)
   - Rollback-Prozedur dokumentieren

3. ✅ **Kommunikation**
   - IT-Team schulen
   - Benutzer informieren (Explorer-Neustart!)
   - Helpdesk vorbereiten

### Während des Rollouts

1. ✅ **Phased Rollout**
   - Pilot: 10-20 PCs
   - Warten: 1 Woche
   - Schrittweise Ausweitung

2. ✅ **Monitoring**
   - Log-Dateien zentral sammeln
   - JSON-Reports auswerten
   - Fehlerquote überwachen

3. ✅ **Support**
   - Hotline bereitstellen
   - FAQ-Dokument
   - Eskalationspfad

### Nach dem Rollout

1. ✅ **Wartung**
   - Monatliche Überprüfung (`Test-CopilotPresence.ps1`)
   - Windows Update Monitoring
   - Script-Updates bei neuen Copilot-Varianten

2. ✅ **Dokumentation**
   - Erfolgreiche Deployments dokumentieren
   - Probleme & Lösungen sammeln
   - Knowledge Base aktualisieren

---

## 9️⃣ Zentrale Log-Sammlung

### Log-Pfade

| Script | Standard-Pfad |
|--------|---------------|
| Remove-CopilotComplete.ps1 | `$env:LOCALAPPDATA\CopilotRemoval\Log_*.txt` |
| Test-CopilotPresence.ps1 | `$env:LOCALAPPDATA\CopilotRemoval\CopilotMonitoring_*.log` |
| Backup & Reports | `$env:LOCALAPPDATA\CopilotRemoval\Backup_*\` |

### Logs auf Netzlaufwerk kopieren

```powershell
# Per GPO-Script (Shutdown)
$LogShare = "\\server\logs\CopilotRemoval\$env:COMPUTERNAME"
New-Item -Path $LogShare -ItemType Directory -Force -ErrorAction SilentlyContinue
Copy-Item "$env:LOCALAPPDATA\CopilotRemoval\*.txt" $LogShare -Force -ErrorAction SilentlyContinue
Copy-Item "$env:LOCALAPPDATA\CopilotRemoval\*.json" $LogShare -Force -ErrorAction SilentlyContinue
```

### JSON-Report Auswertung

```powershell
# Alle Reports sammeln und auswerten
$Reports = Get-ChildItem "\\server\logs\CopilotRemoval\*\*.json"
$Reports | ForEach-Object {
    $Report = Get-Content $_.FullName | ConvertFrom-Json
    [PSCustomObject]@{
        Computer = $Report.Computer
        User = $Report.User
        Date = $Report.StartTime
        Mode = $Report.Mode
        Errors = $Report.Statistics.Errors
        Warnings = $Report.Statistics.Warnings
        Success = $Report.Statistics.Successes
    }
} | Export-Csv "CopilotRemoval_Summary.csv" -NoTypeInformation
```

---

## 🔒 Sicherheit & Compliance

### Lizenzkonformität

✅ **KEINE Lizenzvertragsverletzung**
- Copilot ist optionale Software
- Vergleichbar mit Deaktivierung von Cortana/OneDrive
- Microsoft erlaubt Deaktivierung

📖 **Offizielle Microsoft-Dokumentation:** <a href="https://learn.microsoft.com/en-us/windows/client-management/manage-windows-copilot" target="_blank">Manage Windows Copilot</a>

### DSGVO-Konformität

✅ **Datenschutzrechtlich geboten**
- Verhindert ungewollte Datenübertragung
- Cloud-KI-Features ohne Einwilligung problematisch
- Dokumentation der Maßnahmen

### Change Management

**Dokumentationspflicht:**
- Log-Dateien aufbewahren (12 Monate)
- Backup-Verzeichnisse (90 Tage)
- JSON-Reports dauerhaft (<100 KB)

**Rollback-Plan:**
- Registry-Backups verfügbar
- Hosts-Datei Backup
- Systemwiederherstellungspunkt

---

## 🆘 Troubleshooting

### Problem: Script hängt bei Registry-Phase

**Ursache:** Netzwerk-Registry-Pfade oder langsame Festplatte

**Lösung:**
```powershell
# Monitoring aktivieren
.\Remove-CopilotComplete.ps1 -LogOnly
# Log prüfen für Hinweise
```

### Problem: AppLocker-Merge schlägt fehl

**Ursache:** Existierende Policy nicht kompatibel

**Lösung:**
```powershell
# Mit -Force überschreiben
.\Remove-CopilotComplete.ps1 -Force
```

### Problem: Domain-GPO überschreibt Änderungen

**Ursache:** `gpupdate /force` in Phase 8 überschreibt lokale Einstellungen

**Lösung:**
```powershell
# NoGPUpdate verwenden
.\Remove-CopilotComplete.ps1 -NoGPUpdate
```

### Problem: RDS Multi-User-Konflikte

**Ursache:** Alle User nutzen gleiche Pfade

**Lösung:**
```powershell
# UseTemp für user-spezifische Pfade
.\Remove-CopilotComplete.ps1 -UseTemp -Unattended
```

### Problem: "Das Laufwerk wurde nicht gefunden" (HKCR) ✨ NEU

**Ursache:** HKCR: PSDrive nicht automatisch erstellt

**Lösung:** ✅ Behoben in v2.1.3 Hotfix 1 - Script erstellt HKCR: PSDrive automatisch

### Problem: Copilot reinstalliert nach Windows Update

**Ursache:** Provisionierte Pakete oder Store Auto-Update

**Lösung:** ✅ Behoben in v2.1.3 - 5 Schutz-Ebenen implementiert:
- Provisioned Package Removal
- Deprovisioned Registry Keys
- Store BlockedPackages
- AppLocker Rules
- Protocol Handler Blocking

---

## 📖 Documentation & Resources

**Official Guides:**
- <a href="README.md" target="_blank">README.md</a> - Project overview
- <a href="DEPLOYMENT-GUIDE.md" target="_blank">DEPLOYMENT-GUIDE.md</a> - This file
- <a href="GPO-DEPLOYMENT-GUIDE.md" target="_blank">GPO-DEPLOYMENT-GUIDE.md</a> - GPO/Intune manual configuration

**Microsoft Documentation:**
- <a href="https://learn.microsoft.com/en-us/windows/client-management/manage-windows-copilot" target="_blank">Manage Windows Copilot</a>
- <a href="https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/create-a-rule-for-packaged-apps" target="_blank">Create a rule for packaged apps</a>
- <a href="https://support.microsoft.com/en-us/office/turn-off-copilot-in-microsoft-365-apps-bc7e530b-152d-4123-8e78-edc06f8b85f1" target="_blank">Turn off Copilot in M365 Apps</a>

---

## 📝 Changelog

### v2.1.3 (November 2025) - Current

**Reinstallation Prevention:**
- ✨ **Provisioned Package Removal** - Verhindert Installation für neue Windows-User
- ✨ **Deprovisioned Registry Keys** - Feature Update Reinstallation blockiert (5 Package Family Names)
- ✨ **AppLocker Enhanced** - 5 Deny Rules (3x FilePublisher + 2x FilePath)
- ✨ **Protocol Handler Blocking** - ms-copilot://, microsoft-edge-holographic://, ms-windows-ai-copilot://
- ✨ **Store Auto-Update Blocking** - 5 Copilot-Pakete blockiert (Store bleibt funktional!)

**Technische Details:**
- 📊 Phase 1b: Create-DeprovisionedKeys() - HKLM Registry
- 📊 Phase 4: AppLocker XML-Policy mit Merge-Modus
- 📊 Phase 4b: Block-CopilotProtocolHandlers() - HKCR Registry (mit PSDrive creation)
- 📊 Phase 4c: Block-CopilotStoreAutoUpdate() - BlockedPackages Registry
- 🐛 Hotfix 1: HKCR PSDrive creation (verhindert "Laufwerk nicht gefunden" Fehler)

**Statistik:**
- +250 Zeilen Code
- 3 neue Funktionen
- 3 neue Phasen (1b, 4b, 4c)
- 5 Reinstallations-Vektoren blockiert

### v2.1.2 (November 2025)

**Neue Features:**
- ✨ Microsoft 365 Copilot vollständig blockiert (Word, Excel, PowerPoint, Outlook, OneNote)
- ✨ 13 neue Registry-Einstellungen für M365 Copilot
- ✨ Test-CopilotPresence.ps1 v1.1 - M365 Copilot Monitoring

**Technische Details:**
- Registry-Einstellungen erhöht von 20 auf 33
- Main Toggle: TurnOffCopilot (HKCU/HKLM)
- Per-App: DisableCopilot für jede Office-Anwendung
- Additional: AllowCopilot + DisableCopilotInOffice

### v2.1.1 (November 2025)

**Neue Features:**
- ✨ Unattended-Modus für vollautomatisches Deployment
- ✨ NoGPUpdate-Parameter verhindert Domain-GPO-Konflikte
- ✨ UseTemp-Parameter für RDS/Terminal Server
- ✨ BackupDir-Parameter für Netzwerk-Backups
- ✨ Performance: Registry-Operationen 75% schneller

**Bugfixes:**
- 🐛 Test-CopilotPresence.ps1: Unicode-Zeichen entfernt
- 🐛 Enable-WDACCopilotBlock.ps1: Deny-Regeln korrekt eingefügt
- 🐛 JSON-Serialization: Hanging behoben

### v2.1 (November 2025)

- ✨ 20 Registry-Einstellungen (Copilot-Hardwaretaste, Recall, Office, Game Bar)
- ✨ 6 DNS-Domains gezielt blockiert
- ✨ WDAC-Support für Enterprise

### v2.0 (November 2025)

- ✨ Rollback-Funktionalität
- ✨ JSON-Report
- ✨ Progress-Anzeige

---

**Status:** ✅ Production Ready
**Getestet auf:** Windows 10 22H2, Windows 11 24H2, Windows 11 Build 26200
**Letztes Update:** November 2025 (v2.1.3)
**Neu:** Reinstallation Prevention (5 Schutz-Ebenen)
