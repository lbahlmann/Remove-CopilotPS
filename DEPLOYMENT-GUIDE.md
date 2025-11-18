# Copilot Removal - Deployment Guide v2.1.2

Vollständige Anleitung zum Deployment des Microsoft Copilot Removal Toolkit in Unternehmensumgebungen.

**Version:** 2.1.2 (November 2025)
**Status:** ✅ Production Ready

---

## 📋 Übersicht

Dieses Toolkit entfernt Microsoft Copilot vollständig und verhindert Neuinstallation durch:
- App-Paket Entfernung
- 33 Registry-Einstellungen (inkl. Microsoft 365 Copilot)
- 6 DNS-Domain-Blockierungen
- AppLocker-Regeln (Pro/Enterprise)
- Firewall-Regeln
- Scheduled Task Deaktivierung

---

## 🆕 Neu in v2.1.2

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
   - Name: `Remove Microsoft Copilot`
   - Description: `Vollständige Entfernung und Blockierung von Microsoft Copilot`
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
   - Software Version: `2.1.1`

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

### Prüfungen

1. App-Pakete (installiert & provisioniert)
2. Registry: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot\TurnOffWindowsCopilot`
3. Kontextmenü: Shell Extension GUID `{CB3B0003-8088-4EDE-8769-8B354AB2FF8C}` blockiert

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

---

## 📖 Documentation

**Documentation:**
- README.md - Overview
- DEPLOYMENT-GUIDE.md - This file

---

## 📝 Changelog

### v2.1.2 (November 2025) - Current

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
**Getestet auf:** Windows 10 22H2, Windows 11 24H2
**Letztes Update:** November 2025 (v2.1.2)
**Neu:** Microsoft 365 Copilot vollständig blockiert
