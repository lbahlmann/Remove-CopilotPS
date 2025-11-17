# Copilot Removal - Deployment Guide v2.1

## 🆕 Was ist neu in v2.1? (November 2025)

Die folgenden High-Priority Features wurden hinzugefügt:

✅ **Copilot-Hardwaretaste blockieren** - Neue Tastaturen mit dedizierter Copilot-Taste werden umgeleitet
✅ **Windows Recall deaktivieren** - Screenshot-Aufzeichnung auf Copilot+ PCs blockiert
✅ **Click-To-Do deaktivieren** - Kontextuelle KI-Aktionen (Windows + Q) ausgeschaltet
✅ **Office Connected Experiences** - Alle cloudbasierten KI-Features in Office deaktiviert
✅ **Game Bar Copilot** - Gaming-KI-Assistent deaktiviert
✅ **Erweiterte Firewall-Domains** - Zusätzliche Bing/Copilot-Endpunkte blockiert
✅ **WDAC-Support** - Optionales Script für Kernel-Ebene Blockierung (Enterprise)

---

## Übersicht

Dieses Paket enthält verbesserte Scripts zur vollständigen Entfernung und Blockierung von Microsoft Copilot auf Windows 10/11 Systemen.

### Enthaltene Scripts

| Script | Zweck | Verwendung |
|--------|-------|------------|
| ⭐ `Remove-MicrosoftCopilot.ps1` | **All-In-One Script** - 4 Modi in 1 Datei | EMPFOHLEN! Alle Funktionen vereint |
| `Remove-CopilotComplete.ps1` | Hauptscript zur Copilot-Entfernung (v2.1) | Einmalige Ausführung oder GPO-Deployment |
| `Test-CopilotPresence.ps1` | Monitoring & Überprüfung (v2.1) | Regelmäßige Überprüfung (Scheduled Task) |
| `Detect-CopilotRemoval.ps1` | Detection für SCCM/Intune | Als Detection Method in SCCM/Intune |
| `Enable-WDACCopilotBlock.ps1` | WDAC Kernel-Blockierung | Optional für Enterprise |

---

## 1. Remove-CopilotComplete.ps1 (Hauptscript)

### Neue Features in v2.0

✅ **Rollback-Funktionalität**
- Automatisches Backup aller Registry-Änderungen
- `.reg` Dateien für einfachen Rollback
- Backup von Scheduled Tasks
- Backup der Hosts-Datei

✅ **Windows-Version-Erkennung**
- Automatische Erkennung von Windows 10 vs Windows 11
- Versionsspezifische Paketlisten
- Edition-Prüfung (Home/Pro/Enterprise)

✅ **Dynamische Pfaderkennung**
- Keine hardcodierten Versionsnummern mehr
- Sucht Copilot.exe in allen relevanten Pfaden
- Unterstützt zukünftige Windows-Updates

✅ **AppLocker-Verbesserungen**
- Prüfung vor Merge existierender Regeln
- Backup der AppLocker-Policy
- `-Force` Parameter zum Überschreiben

✅ **Verbesserte Hosts-Datei Behandlung**
- Regex-basierte Duplikat-Prüfung
- Backup der Hosts-Datei
- Automatischer DNS-Cache-Clear

✅ **Office-Versionserkennung**
- Unterstützt Office 2013, 2016, 2019, 2021, 2024
- Automatische Erkennung installierter Versionen

✅ **Progress-Anzeige**
- Write-Progress für alle Phasen
- Besseres Benutzer-Feedback

✅ **JSON-Report**
- Strukturierter Execution Report
- Statistiken (Erfolge, Warnungen, Fehler)
- Maschinenlesbar für Automatisierung

✅ **Explorer-Neustart-Warnung**
- Bestätigungsdialog (außer bei `-Force`)
- Verhindert Datenverlust

### Parameter

```powershell
.\Remove-CopilotComplete.ps1 [-LogOnly] [-NoRestart] [-NoBackup] [-Force] [-LogPath <path>]
```

| Parameter | Beschreibung |
|-----------|--------------|
| `-LogOnly` | Testlauf ohne Änderungen (empfohlen für erste Tests) |
| `-NoRestart` | Unterdrückt Neustart-Prompt |
| `-NoBackup` | Überspringt Backup-Erstellung (nicht empfohlen) |
| `-Force` | Unterdrückt alle Bestätigungsdialoge |
| `-LogPath` | Pfad zur Log-Datei (Standard: C:\Temp\CopilotRemoval_TIMESTAMP.log) |

### Verwendungsbeispiele

#### Test-Ausführung
```powershell
# Testlauf ohne Änderungen - IMMER ZUERST AUSFÜHREN!
.\Remove-CopilotComplete.ps1 -LogOnly
```

#### Produktiv-Ausführung (interaktiv)
```powershell
# Mit Bestätigungsdialogen
.\Remove-CopilotComplete.ps1
```

#### Automatisierte Ausführung
```powershell
# Für GPO/Intune/SCCM - keine Dialoge, kein Neustart
.\Remove-CopilotComplete.ps1 -NoRestart -Force
```

### Backup & Rollback

**Backup-Verzeichnis:**
```
C:\Temp\CopilotRemoval_Backup_TIMESTAMP\
├── README.txt                          # Rollback-Anleitung
├── HKLM_SOFTWARE_Policies_*.reg        # Registry-Backups
├── AppLockerPolicy_Backup.xml          # AppLocker-Backup
├── hosts.backup                        # Hosts-Datei Backup
├── Task_*.xml                          # Scheduled Task Backups
└── ExecutionReport.json                # Detaillierter Report
```

**Rollback durchführen:**
1. Zum Backup-Verzeichnis navigieren
2. Gewünschte `.reg` Datei doppelklicken
3. Import bestätigen
4. Computer neu starten

**Hosts-Datei wiederherstellen:**
```powershell
Copy-Item "C:\Temp\CopilotRemoval_Backup_*\hosts.backup" "$env:SystemRoot\System32\drivers\etc\hosts" -Force
```

### Exit Codes

| Code | Bedeutung |
|------|-----------|
| 0 | Erfolgreich abgeschlossen |
| 1 | Fehler - Admin-Rechte fehlen |

---

## 2. Test-CopilotPresence.ps1 (Monitoring)

### Zweck

Regelmäßige Überprüfung, ob Copilot wieder auf dem System erschienen ist (z.B. nach Windows Updates).

### Parameter

```powershell
.\Test-CopilotPresence.ps1 [-EmailAlert <email>] [-SMTPServer <server>] [-CreateScheduledTask] [-LogPath <path>]
```

| Parameter | Beschreibung |
|-----------|--------------|
| `-EmailAlert` | E-Mail-Adresse für Benachrichtigungen |
| `-SMTPServer` | SMTP-Server für E-Mail-Versand |
| `-CreateScheduledTask` | Erstellt monatlichen Scheduled Task |
| `-LogPath` | Pfad zur Log-Datei |

### Verwendungsbeispiele

#### Manuelle Überprüfung
```powershell
.\Test-CopilotPresence.ps1
```

#### Mit E-Mail-Benachrichtigung
```powershell
.\Test-CopilotPresence.ps1 -EmailAlert admin@firma.de -SMTPServer mail.firma.de
```

#### Scheduled Task erstellen
```powershell
# Erstellt monatlichen Task (1. des Monats, 08:00 Uhr)
.\Test-CopilotPresence.ps1 -CreateScheduledTask
```

Der Scheduled Task:
- Läuft als SYSTEM
- Monatlich am 1. um 08:00 Uhr
- Speichert Log in `C:\Temp\CopilotMonitoring_DATUM.log`
- Task Name: `Copilot-Monitoring`

### Exit Codes

| Code | Bedeutung |
|------|-----------|
| 0 | Sauber - Kein Copilot gefunden |
| 1 | Copilot gefunden - Aktion erforderlich |
| 2 | Blockierungen unvollständig - Warnungen vorhanden |

### Überprüfungen

Das Script prüft:
- ✅ App-Pakete (installiert & provisioniert)
- ✅ Registry-Einstellungen (HKLM & HKCU)
- ✅ Kontextmenü-Blockierung
- ✅ Hosts-Datei Einträge
- ✅ Firewall-Regeln
- ✅ Scheduled Tasks (aktiv/inaktiv)

---

## 3. Detect-CopilotRemoval.ps1 (SCCM/Intune)

### Zweck

Detection Method für SCCM/ConfigMgr und Microsoft Intune Deployments.

### Exit Codes

| Code | Bedeutung | SCCM/Intune Interpretation |
|------|-----------|---------------------------|
| 0 | Copilot NICHT gefunden | COMPLIANT (Installation nicht erforderlich) |
| 1 | Copilot gefunden | NON-COMPLIANT (Installation erforderlich) |

### Verwendung in SCCM/ConfigMgr

#### Application erstellen

1. **General Information**
   - Name: `Remove Microsoft Copilot`
   - Publisher: `Your Organization`
   - Software Version: `2.1`

2. **Deployment Type** → **Script Installer**

   **Content Location:** `\\server\share\CopilotRemoval\`

   **Installation Program:**
   ```cmd
   powershell.exe -ExecutionPolicy Bypass -File "Remove-CopilotComplete.ps1" -NoRestart -Force
   ```

   **Uninstall Program:** (leer lassen)

3. **Detection Method** → **Use a custom script**

   **Script Type:** PowerShell

   **Script file:** `Detect-CopilotRemoval.ps1`

   ☑ Run script as 32-bit process on 64-bit clients: **No**

   ☑ Run script using logged on credentials: **No**

4. **User Experience**
   - Installation behavior: **Install for system**
   - Logon requirement: **Whether or not a user is logged on**
   - Installation program visibility: **Hidden**
   - Maximum allowed run time: **60 minutes**
   - Estimated installation time: **15 minutes**

5. **Requirements**
   - Operating System: **Windows 10** oder **Windows 11**
   - Minimum OS version: **Windows 10 1809** (Build 17763)

#### Deployment konfigurieren

**Deploy to Collection:**
- Purpose: **Required**
- Available: `Sofort`
- Deadline: `Nach Bedarf`
- Rerun behavior: **Rerun if failed previous attempt**
- User notifications: **Display in Software Center and show all notifications**

### Verwendung in Microsoft Intune

#### App erstellen

1. **Apps** → **All apps** → **Add**

2. **App type:** `Windows app (Win32)`

3. **App package file**
   - Erstellen Sie eine `.intunewin` Datei:
   ```powershell
   # IntuneWinAppUtil.exe herunterladen
   .\IntuneWinAppUtil.exe -c "C:\Source\CopilotRemoval" -s "Remove-CopilotComplete.ps1" -o "C:\Output"
   ```

4. **App information**
   - Name: `Remove Microsoft Copilot`
   - Description: `Vollständige Entfernung und Blockierung von Microsoft Copilot`
   - Publisher: `Your Organization`
   - Category: `IT Tools`

5. **Program**

   **Install command:**
   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File "Remove-CopilotComplete.ps1" -NoRestart -Force
   ```

   **Uninstall command:** (leer lassen)

   **Install behavior:** `System`

   **Device restart behavior:** `Determine behavior based on return codes`

6. **Requirements**
   - Operating system architecture: **64-bit**
   - Minimum operating system: **Windows 10 1809**

7. **Detection rules**

   **Rule format:** `Use a custom detection script`

   **Script file:** `Detect-CopilotRemoval.ps1`

   **Run script as 32-bit:** `No`

   **Enforce script signature check:** `No`

8. **Return codes**

   | Code | Type |
   |------|------|
   | 0 | Success |
   | 1 | Failed |

9. **Assignment**
   - Required: `All Devices` oder spezifische Gruppe
   - Available for enrolled devices: Optional
   - End user notifications: `Show all toast notifications`

---

## 4. Deployment-Strategien

### Option A: Gruppenrichtlinie (GPO)

**Vorteile:**
- Einfache Verwaltung
- Automatische Anwendung bei Domänen-PCs
- Keine zusätzliche Infrastruktur

**Nachteile:**
- Keine Reporting-Funktionen
- Schwierigere Fehleranalyse

**Konfiguration:**

1. Script auf Netzlaufwerk kopieren:
   ```
   \\domain.local\NETLOGON\Scripts\CopilotRemoval\Remove-CopilotComplete.ps1
   ```

2. GPO erstellen:
   - `Computer Configuration` → `Policies` → `Windows Settings` → `Scripts` → `Startup`

3. PowerShell Script hinzufügen:
   - Script Name: `\\domain.local\NETLOGON\Scripts\CopilotRemoval\Remove-CopilotComplete.ps1`
   - Script Parameters: `-NoRestart -Force -LogPath "C:\Windows\Logs\CopilotRemoval.log"`

4. GPO verknüpfen:
   - Ziel-OU auswählen
   - Sicherheitsfilterung konfigurieren

5. Monitoring einrichten:
   - Scheduled Task für `Test-CopilotPresence.ps1` per GPO verteilen

### Option B: Microsoft Intune

**Vorteile:**
- Cloud-basiert
- Umfassendes Reporting
- Deployment-Status pro Gerät

**Nachteile:**
- Intune-Lizenz erforderlich
- Setup-Aufwand

**Siehe Abschnitt "Verwendung in Microsoft Intune" oben**

### Option C: SCCM/ConfigMgr

**Vorteile:**
- On-Premises Kontrolle
- Detailliertes Reporting
- Phased Rollout möglich

**Nachteile:**
- SCCM-Infrastruktur erforderlich
- Komplexere Konfiguration

**Siehe Abschnitt "Verwendung in SCCM/ConfigMgr" oben**

### Option D: Manuelle Ausführung

**Für kleine Umgebungen oder Tests**

1. Script auf Ziel-PC kopieren
2. PowerShell als Administrator öffnen
3. Testlauf:
   ```powershell
   .\Remove-CopilotComplete.ps1 -LogOnly
   ```
4. Produktiv-Ausführung:
   ```powershell
   .\Remove-CopilotComplete.ps1
   ```
5. Monitoring einrichten:
   ```powershell
   .\Test-CopilotPresence.ps1 -CreateScheduledTask
   ```

---

## 5. Best Practices

### Vor dem Rollout

1. ✅ **Testumgebung**
   - Verschiedene Windows-Versionen (10/11)
   - Verschiedene Editionen (Home/Pro/Enterprise)
   - Mit/ohne Office-Installation
   - Domänen-PC vs. Standalone

2. ✅ **Backup-Strategie**
   - Systemwiederherstellungspunkt erstellen
   - Backup-Verzeichnis auf Netzlaufwerk speichern
   - Rollback-Prozedur dokumentieren

3. ✅ **Kommunikation**
   - IT-Team schulen
   - Benutzer informieren (Explorer-Neustart!)
   - Helpdesk vorbereiten

### Während des Rollouts

1. ✅ **Phased Rollout**
   - Start mit Pilotgruppe (10-20 PCs)
   - Warten auf Feedback (1 Woche)
   - Schrittweise Ausweitung

2. ✅ **Monitoring**
   - Log-Dateien zentral sammeln
   - Execution Reports auswerten
   - Fehlerquote überwachen

3. ✅ **Support**
   - Hotline bereitstellen
   - FAQ-Dokument erstellen
   - Eskalationspfad definieren

### Nach dem Rollout

1. ✅ **Wartung**
   - Monatliche Überprüfung via `Test-CopilotPresence.ps1`
   - Windows Update Monitoring
   - Script-Updates bei neuen Copilot-Varianten

2. ✅ **Dokumentation**
   - Erfolgreiche Deployments dokumentieren
   - Probleme und Lösungen sammeln
   - Knowledge Base aktualisieren

---

## 6. Log-Auswertung

### Log-Pfade

| Script | Standard-Pfad |
|--------|---------------|
| Remove-CopilotComplete.ps1 | `C:\Temp\CopilotRemoval_YYYYMMDD_HHMMSS.log` |
| Test-CopilotPresence.ps1 | `C:\Temp\CopilotMonitoring_YYYYMMDD.log` |
| Backup & Reports | `C:\Temp\CopilotRemoval_Backup_YYYYMMDD_HHMMSS\` |

### Log-Level

| Level | Bedeutung |
|-------|-----------|
| `[Info]` | Informationsmeldung |
| `[Success]` | Erfolgreiche Aktion |
| `[Warning]` | Warnung (nicht kritisch) |
| `[Error]` | Fehler (kritisch) |

### Statistiken im JSON-Report

```json
{
  "Timestamp": "2025-11-17 14:30:00",
  "Computer": "PC-001",
  "User": "SYSTEM",
  "WindowsVersion": "Microsoft Windows 11 Pro",
  "IsWindows11": true,
  "Mode": "Production",
  "Statistics": {
    "Errors": 0,
    "Warnings": 2,
    "Successes": 47
  },
  "TestResult": {
    "Success": true,
    "Issues": [],
    "Checks": [...]
  }
}
```

### Zentrale Log-Sammlung (optional)

```powershell
# Kopiere Logs auf Netzlaufwerk
$LogShare = "\\server\share\CopilotRemoval-Logs\$env:COMPUTERNAME"
New-Item -Path $LogShare -ItemType Directory -Force
Copy-Item "C:\Temp\CopilotRemoval*.log" $LogShare -Force
Copy-Item "C:\Temp\CopilotRemoval_Backup_*\ExecutionReport.json" $LogShare -Force
```

---

## 7. Sicherheit & Compliance

### Lizenzkonformität

✅ Die Entfernung von Copilot verletzt **keine** Microsoft-Lizenzbedingungen
✅ Copilot ist optionale Software, keine Kernkomponente
✅ Vergleichbar mit Deaktivierung von Cortana oder OneDrive

### DSGVO-Konformität

✅ Deaktivierung von AI-Features kann datenschutzrechtlich **geboten** sein
✅ Verhinderung ungewollter Datenübertragung an Microsoft-Cloud
✅ Dokumentation der Maßnahmen (Log-Dateien aufbewahren!)

### Change Management

**Dokumentationspflicht:**
- Alle Änderungen werden geloggt
- Backups ermöglichen Rollback
- Execution Reports als Nachweis

**Aufbewahrung:**
- Log-Dateien: 12 Monate
- Backup-Verzeichnisse: 90 Tage
- JSON-Reports: Dauerhaft (klein, <100 KB)

---

## 8. Support & Contribution

**Entwickelt von:**
Lars Bahlmann
badata GmbH - IT Systemhaus in Bremen
www.badata.de

**Support:** Für technischen Support wenden Sie sich bitte an unser Support-Team.

**Documentation:** See README.md and this deployment guide for comprehensive documentation.

---

## 9. Changelog

### Version 2.1 (November 2025)
- ⭐ **Remove-MicrosoftCopilot.ps1**: All-In-One Script (4 Modi in 1 Datei)
- ✨ Copilot-Hardwaretaste blockieren/umleiten
- ✨ Windows Recall deaktivieren (Copilot+ PCs)
- ✨ Click-To-Do KI-Aktionen deaktivieren
- ✨ Office Connected Experiences komplett deaktivieren
- ✨ Game Bar Copilot entfernen
- ✨ Erweiterte Firewall-Domains (Bing-Endpunkte)
- ✨ WDAC-Support für Enterprise (Kernel-Ebene Blockierung)
- ✨ RDS/Terminal Server Support mit user-spezifischen Pfaden
- ✨ Run-Once Protection mit Registry-Tracking
- ✨ Unattended Mode für vollautomatische Deployments

### Version 2.0 (November 2025)
- ✨ Rollback-Funktionalität hinzugefügt
- ✨ Windows-Version-Erkennung
- ✨ Dynamische Pfaderkennung
- ✨ AppLocker-Verbesserungen
- ✨ Verbesserte Hosts-Datei Behandlung
- ✨ Office-Versionserkennung
- ✨ Progress-Anzeige
- ✨ JSON-Report
- ✨ Explorer-Neustart-Warnung
- 🐛 Fix: Hardcodierte Pfade entfernt
- 🐛 Fix: AppLocker Merge überschreibt nicht mehr
- 🐛 Fix: Hosts-File Duplikate
- 📚 Umfassende Deployment-Dokumentation

### Version 1.0 (November 2025)
- Initial Release
- 10-Phasen-Strategie implementiert
- Basis-Funktionalität

---

**Stand:** November 2025
**Version:** 2.1
**Nächstes Review:** Februar 2026
