# Copilot Removal - Deployment Guide v2.2.1

Vollständige Anleitung zum Deployment des Microsoft Copilot Removal Toolkit in Unternehmensumgebungen.

**Version:** 2.2.1 (Dezember 2025)
**Status:** ✅ Production Ready

---

## 📋 Übersicht

Dieses Toolkit entfernt Microsoft Copilot vollständig und verhindert Neuinstallation durch:
- **Phase 0:** Prozess-Beendigung ✨ NEU v2.2
- **Phase 1:** App-Paket Entfernung (installiert + provisioniert)
- **Phase 1b:** Deprovisioned Registry Keys
- **Phase 2:** 33 Registry-Einstellungen (inkl. Microsoft 365 Copilot) + HKU-Iteration ✨ NEU v2.2
- **Phase 3:** Kontextmenü-Blockierung
- **Phase 4:** AppLocker-Regeln (7 Rules: Publisher + Path) ✨ ENHANCED v2.2
- **Phase 4b:** Protocol Handler Blockierung
- **Phase 4c:** Store Auto-Update Blockierung
- **Phase 5:** 6 DNS-Domain-Blockierungen
- **Phase 6:** Scheduled Task Deaktivierung (eigener Task ausgenommen) 🐛 FIX v2.2.1
- **Phase 7:** Firewall-Regeln

---

## 🆕 Neu in v2.2.1 (Hotfix)

🐛 **Self-Sabotage Bug behoben** - Phase 6 deaktiviert nicht mehr den eigenen "Copilot-Removal" Task
🐛 **Task-Erstellung robuster** - Verwendet jetzt direkt schtasks.exe mit XML (statt PowerShell)
🐛 **GPO-Deployment** - `-Unattended` Parameter in Deploy-CopilotRemoval.cmd hinzugefügt
🐛 **Versions-Tracking** - Script prüft Version vor erneuter Ausführung (verhindert 33x Ausführung bei GPO)
🐛 **Backup/Log-Pfade vereinheitlicht** - Beide unter `C:\ProgramData\badata\CopilotRemoval\`

## Neu in v2.2

✅ **Self-Elevation (UAC)** - Automatischer Admin-Prompt für Non-Admin User
✅ **Phase 0: Prozess-Beendigung** - Copilot-Prozesse werden vor Entfernung beendet
✅ **Zentrale Log-Location** - `C:\ProgramData\badata\CopilotRemoval\Logs\` mit User-Kontext
✅ **HKU-Iteration** - Registry-Änderungen für alle User-Profile (nicht nur HKCU)
✅ **Scheduled Task Support** - Automatische Wartung mit `-CreateScheduledTask`
✅ **WebExperience Pattern** - MicrosoftWindows.Client.WebExperience wird erkannt
✅ **MicrosoftOfficeHub Pattern** - "Microsoft 365 Copilot" App wird entfernt
✅ **AppLocker Enhanced** - 7 Deny Rules (vorher 5: +WebExperience Publisher & Path)
✅ **Task-Persistenz** - schtasks.exe Fallback für zuverlässige Task-Erstellung
✅ **CMD-Wrapper** - Deploy-CopilotRemoval.cmd für einfaches Deployment

## Neu in v2.1.3

✅ **Provisioned Package Removal** - Verhindert Installation für neue Windows-User
✅ **Deprovisioned Registry Keys** - 5 Package Family Names (Feature Update Reinstallation Prevention)
✅ **Protocol Handler Blockierung** - ms-copilot://, microsoft-edge-holographic://, ms-windows-ai-copilot://
✅ **Store Auto-Update Blockierung** - 5 Copilot-Pakete blockiert (Store bleibt funktional!)

## Neu in v2.1.2

✅ **Microsoft 365 Copilot Blockierung** - Vollständig in Word, Excel, PowerPoint, Outlook, OneNote
✅ **13 neue Registry-Keys** - Per-Application Controls
✅ **Enhanced Monitoring** - Test-Script prüft M365 Copilot

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

### Mit Scheduled Task (empfohlen)

```powershell
.\Remove-CopilotComplete.ps1 -Unattended -CreateScheduledTask -TaskSchedule Weekly
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
    [-CreateScheduledTask]  # NEU v2.2: Scheduled Task erstellen
    [-TaskSchedule <Daily|Weekly|Monthly>]  # NEU v2.2: Task-Intervall
    [-WithReboot]        # NEU v2.2: Automatischer Reboot
```

### 11-Phasen-Strategie (v2.2)

0. **Prozess-Beendigung** ✨ NEU - Copilot-Prozesse werden beendet
1. **App-Paket Entfernung** - AppX-Pakete (installiert + provisioniert)
2. **Deprovisioned Keys** - Feature Update Reinstallation Prevention
3. **Registry-Konfiguration** - 33 Einstellungen + HKU-Iteration für alle User
4. **Kontextmenü-Blockierung** - Shell Extension GUID
5. **AppLocker-Regeln** ✨ ENHANCED - 7 Deny Rules (Publisher + Path)
6. **Protocol Handler** - ms-copilot:// blockiert
7. **Store Auto-Update** - Copilot-Pakete blockiert (Store funktional!)
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

#### Szenario 4: Mit Scheduled Task (empfohlen)

```powershell
# Wöchentlicher Task für automatische Wartung
.\Remove-CopilotComplete.ps1 -Unattended -CreateScheduledTask -TaskSchedule Weekly
```

#### Szenario 5: Backup auf Netzlaufwerk

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

### Zentrale Logs (v2.2)

```
C:\ProgramData\badata\CopilotRemoval\Logs\
├── Log_YYYYMMDD_HHMMSS_User-<Username>.txt    # User-Ausführung
└── Log_YYYYMMDD_HHMMSS_SYSTEM-Task.txt        # Scheduled Task
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

### Reinstallation Prevention (v2.2)

✅ **5 Schutz-Ebenen gegen Neuinstallation:**

1. **Provisioned Package Removal** - Entfernt AppX Provisioned Packages (Get-AppxProvisionedPackage)
2. **Deprovisioned Registry Keys** - HKLM:\...\Appx\AppxAllUserStore\Deprovisioned\{PackageFamilyName}
3. **AppLocker Rules** - Application-Level Enforcement (7 Rules: 5x Publisher, 2x Path)
4. **Protocol Handler Blocking** - HKCR Registry Keys (ms-copilot, microsoft-edge-holographic, ms-windows-ai-copilot)
5. **Store Auto-Update Blocking** - HKLM:\...\Appx\AppxAllUserStore\BlockedPackages + Optional Features

### Package Family Names v2.2 (6)

```
Microsoft.Copilot_8wekyb3d8bbwe
Microsoft.Windows.Ai.Copilot.Provider_8wekyb3d8bbwe
MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy
Microsoft.WindowsCopilot_8wekyb3d8bbwe
Microsoft.Windows.Copilot_8wekyb3d8bbwe
Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe  ← NEU v2.2
```

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
   - Script Parameters: `-Unattended -NoGPUpdate -CreateScheduledTask`

4. **GPO verknüpfen**
   - Ziel-OU auswählen
   - Sicherheitsfilterung konfigurieren

5. **Optional: Monitoring einrichten**
   - Scheduled Task für `Test-CopilotPresence.ps1` per GPO verteilen

### Empfohlene Parameter

```
-Unattended -NoGPUpdate -CreateScheduledTask -TaskSchedule Weekly
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
   - Name: `Remove Microsoft Copilot v2.2`
   - Description: `Vollständige Entfernung und Blockierung von Microsoft Copilot - Self-Elevation, Scheduled Tasks, Zentrale Logs`
   - Publisher: `Your Organization`

5. **Program**

   **Install command:**
   ```
   powershell.exe -ExecutionPolicy Bypass -File "Remove-CopilotComplete.ps1" -Unattended -CreateScheduledTask
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
   - Software Version: `2.2`

2. **Deployment Type** → Script Installer

   **Content Location:**
   ```
   \\server\share\CopilotRemoval\
   ```

   **Installation Program:**
   ```
   powershell.exe -ExecutionPolicy Bypass -File "Remove-CopilotComplete.ps1" -Unattended -NoGPUpdate -CreateScheduledTask
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
    [-Force]              # NEU: Überspringt Bestätigung
```

### Neue Überprüfungen (v2.2)

✅ **WebExperience** - MicrosoftWindows.Client.WebExperience wird geprüft
✅ **MicrosoftOfficeHub** - "Microsoft 365 Copilot" App wird geprüft
✅ **Deprovisioned Registry Keys** - 6 Package Family Names
✅ **Protocol Handler** - 3 Handler (ms-copilot, microsoft-edge-holographic, ms-windows-ai-copilot)
✅ **Store BlockedPackages** - 6 Copilot-Pakete
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

### Prüfungen (v2.2)

1. App-Pakete (installiert & provisioniert, inkl. WebExperience & MicrosoftOfficeHub)
2. Registry: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot\TurnOffWindowsCopilot`
3. Kontextmenü: Shell Extension GUID `{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}` blockiert
4. **Deprovisioned Keys** - 6 Package Family Names
5. **Store BlockedPackages** - 6 Copilot-Pakete

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
   - Zentrale Log-Dateien prüfen (`C:\ProgramData\badata\CopilotRemoval\Logs\`)
   - JSON-Reports auswerten
   - Fehlerquote überwachen

3. ✅ **Support**
   - Hotline bereitstellen
   - FAQ-Dokument
   - Eskalationspfad

### Nach dem Rollout

1. ✅ **Wartung**
   - Scheduled Task läuft automatisch (Weekly + AtStartup)
   - Monatliche Überprüfung mit `Test-CopilotPresence.ps1`
   - Windows Update Monitoring
   - Script-Updates bei neuen Copilot-Varianten

2. ✅ **Dokumentation**
   - Erfolgreiche Deployments dokumentieren
   - Probleme & Lösungen sammeln
   - Knowledge Base aktualisieren

---

## 9️⃣ Zentrale Log-Sammlung

### Log-Pfade (v2.2)

| Script | Standard-Pfad |
|--------|---------------|
| Remove-CopilotComplete.ps1 (User) | `C:\ProgramData\badata\CopilotRemoval\Logs\Log_*_User-<Username>.txt` |
| Remove-CopilotComplete.ps1 (Task) | `C:\ProgramData\badata\CopilotRemoval\Logs\Log_*_SYSTEM-Task.txt` |
| Test-CopilotPresence.ps1 | `$env:LOCALAPPDATA\CopilotRemoval\CopilotMonitoring_*.log` |
| Backup & Reports | `$env:LOCALAPPDATA\CopilotRemoval\Backup_*\` |

### Logs auf Netzlaufwerk kopieren

```powershell
# Per GPO-Script (Shutdown)
$LogShare = "\\server\logs\CopilotRemoval\$env:COMPUTERNAME"
New-Item -Path $LogShare -ItemType Directory -Force -ErrorAction SilentlyContinue

# Zentrale Logs
Copy-Item "C:\ProgramData\badata\CopilotRemoval\Logs\*.txt" $LogShare -Force -ErrorAction SilentlyContinue

# User-Logs
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

### Problem: "Das Laufwerk wurde nicht gefunden" (HKCR)

**Ursache:** HKCR: PSDrive nicht automatisch erstellt

**Lösung:** ✅ Behoben in v2.1.3 Hotfix 1 - Script erstellt HKCR: PSDrive automatisch

### Problem: Copilot reinstalliert nach Windows Update

**Ursache:** Provisionierte Pakete oder Store Auto-Update

**Lösung:** ✅ Behoben in v2.1.3+ - 5 Schutz-Ebenen implementiert

### Problem: Scheduled Task wird nicht erstellt ✨ NEU v2.2

**Ursache:** PowerShell Register-ScheduledTask Fehler

**Lösung:** ✅ Behoben in v2.2 - schtasks.exe Fallback mit XML-Datei

### Problem: Scheduled Task ist deaktiviert ✨ NEU v2.2

**Ursache:** Register-ScheduledTask aktiviert Task nicht automatisch

**Lösung:** ✅ Behoben in v2.2 - Explizite Aktivierung mit Enable-ScheduledTask

### Problem: WebExperience oder MicrosoftOfficeHub wird nicht entfernt ✨ NEU v2.2

**Ursache:** Pattern wurde nicht erkannt

**Lösung:** ✅ Behoben in v2.2 - Pattern `*WebExperience*` und `*MicrosoftOfficeHub*` hinzugefügt

### Problem: Copilot-Prozesse blockieren Entfernung ✨ NEU v2.2

**Ursache:** Laufende Copilot-Prozesse

**Lösung:** ✅ Behoben in v2.2 - Phase 0 beendet alle Copilot-Prozesse vor Entfernung

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

### v2.2 (Dezember 2025) - Current

**Neue Features:**
- ✨ **Self-Elevation (UAC)** - Automatischer Admin-Prompt für Non-Admin User
- ✨ **Phase 0: Prozess-Beendigung** - Stop-CopilotProcesses beendet Copilot-Prozesse vor Entfernung
- ✨ **Zentrale Log-Location** - C:\ProgramData\badata\CopilotRemoval\Logs\ mit User-Kontext
- ✨ **HKU-Iteration** - Registry-Änderungen für alle User-Profile (Set-RegistryForAllUsers)
- ✨ **Scheduled Task Support** - Neue Parameter -CreateScheduledTask, -TaskSchedule, -WithReboot
- ✨ **WebExperience Pattern** - MicrosoftWindows.Client.WebExperience wird erkannt und entfernt
- ✨ **MicrosoftOfficeHub Pattern** - "Microsoft 365 Copilot" App wird entfernt
- ✨ **AppLocker Enhanced** - 7 Deny Rules (vorher 5: +WebExperience Publisher & Path)
- ✨ **Task-Persistenz** - schtasks.exe Fallback mit XML-Datei für zuverlässige Task-Erstellung
- ✨ **CMD-Wrapper** - Deploy-CopilotRemoval.cmd für einfaches Deployment

**Technische Details:**
- 📊 Phase 0: Stop-CopilotProcesses() - Beendet laufende Copilot-Prozesse
- 📊 HKU-Iteration: Set-RegistryForAllUsers() - Schreibt in alle User-Profile
- 📊 Zentrale Logs: Log_YYYYMMDD_HHMMSS_<Context>.txt (User-xxx / SYSTEM-Task)
- 📊 Scheduled Task: AtStartup + Weekly Trigger, SYSTEM-Kontext
- 📊 AppLocker: 7 Deny Rules (5x FilePublisher + 2x FilePath)
- 📊 Package Patterns: *Copilot*, *WindowsAI*, *WebExperience*, *MicrosoftOfficeHub*
- 📊 6 Package Family Names (vorher 5)

**Bugfixes:**
- 🐛 Task-Aktivierung: Explizite Aktivierung mit Enable-ScheduledTask
- 🐛 Task-Persistenz: schtasks.exe Fallback verhindert Task-Verschwinden nach Reboot
- 🐛 Test-CopilotPresence.ps1: -Force Parameter für nicht-interaktive Ausführung

### v2.1.3 (November 2025)

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

### v2.1.2 (November 2025)

**Neue Features:**
- ✨ Microsoft 365 Copilot vollständig blockiert (Word, Excel, PowerPoint, Outlook, OneNote)
- ✨ 13 neue Registry-Einstellungen für M365 Copilot
- ✨ Test-CopilotPresence.ps1 v1.1 - M365 Copilot Monitoring

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
**Letztes Update:** Dezember 2025 (v2.2)
**Neu:** Self-Elevation, Scheduled Tasks, Zentrale Logs, 7 AppLocker Rules
