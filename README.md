# Microsoft Copilot Removal Toolkit v2.1

Vollständige Entfernung und Blockierung von Microsoft Copilot auf Windows 10/11 Systemen.

**Status:** Production Ready
**Version:** 2.1 (November 2025)
**License:** MIT

---

## 🆕 Neu in v2.1

✅ Copilot-Hardwaretaste blockieren/umleiten
✅ Windows Recall deaktivieren (Copilot+ PCs)
✅ Click-To-Do KI-Aktionen ausschalten
✅ Office Connected Experiences komplett deaktivieren
✅ Game Bar Copilot entfernen
✅ Erweiterte Firewall-Domains
✅ WDAC-Support für Enterprise (Kernel-Ebene)

---

## ⭐ All-In-One Script (EMPFOHLEN!)

**Neu:** Alle Funktionen in einer Datei! `Remove-MicrosoftCopilot.ps1`

```powershell
# Copilot entfernen (Standard)
.\Remove-MicrosoftCopilot.ps1

# Testlauf ohne Änderungen
.\Remove-MicrosoftCopilot.ps1 -LogOnly

# Überprüfung (Monitoring)
.\Remove-MicrosoftCopilot.ps1 -Mode Test

# Monatlichen Check einrichten
.\Remove-MicrosoftCopilot.ps1 -Mode Test -CreateScheduledTask

# Detection für SCCM/Intune
.\Remove-MicrosoftCopilot.ps1 -Mode Detect

# WDAC Kernel-Blockierung (Enterprise)
.\Remove-MicrosoftCopilot.ps1 -Mode WDAC -AuditOnly -Deploy
```

---

## Schnellstart (einzelne Scripts)

### 1. Testlauf (IMMER ZUERST!)
```powershell
.\Remove-CopilotComplete.ps1 -LogOnly
```

### 2. Produktiv-Ausführung
```powershell
.\Remove-CopilotComplete.ps1
```

### 3. Monitoring einrichten
```powershell
.\Test-CopilotPresence.ps1 -CreateScheduledTask
```

---

## Enthaltene Scripts

| Script | Zweck | Dokumentation |
|--------|-------|---------------|
| **Remove-MicrosoftCopilot.ps1** ⭐ | All-In-One Script (EMPFOHLEN!) | [Details](#manage-copilotremovalps1-all-in-one) |
| **Remove-CopilotComplete.ps1** | Hauptscript zur Copilot-Entfernung (v2.1) | [Details](#remove-copilotcompleteps1) |
| **Test-CopilotPresence.ps1** | Monitoring & Überprüfung (v2.1) | [Details](#test-copilotpresenceps1) |
| **Detect-CopilotRemoval.ps1** | Detection für SCCM/Intune | [Details](#detect-copilotremovalps1) |
| **Enable-WDACCopilotBlock.ps1** | WDAC Kernel-Blockierung | [Details](#enable-wdaccopilotblockps1) |

📖 **[Vollständige Deployment-Dokumentation](DEPLOYMENT-GUIDE.md)**

---

## Remove-MicrosoftCopilot.ps1 (All-In-One)

⭐ **EMPFOHLEN**: Vereint alle Funktionen in einer Datei!

### Vorteile

✅ **Eine Datei** statt 4 separate Scripts
✅ **Einfacheres Deployment** (nur eine Datei kopieren)
✅ **Modi-basiert** (Remove, Test, Detect, WDAC)
✅ **Alle v2.1 Features** enthalten
✅ **Gleiche Parameter** wie Einzelscripts

### Modi

```powershell
# MODE: REMOVE (Standard) - Copilot entfernen
.\Remove-MicrosoftCopilot.ps1
.\Remove-MicrosoftCopilot.ps1 -LogOnly              # Testlauf
.\Remove-MicrosoftCopilot.ps1 -Force -NoRestart     # Automatisiert

# MODE: TEST - Monitoring & Überprüfung
.\Remove-MicrosoftCopilot.ps1 -Mode Test
.\Remove-MicrosoftCopilot.ps1 -Mode Test -CreateScheduledTask
.\Remove-MicrosoftCopilot.ps1 -Mode Test -EmailAlert admin@firma.de -SMTPServer mail.firma.de

# MODE: DETECT - SCCM/Intune Detection
.\Remove-MicrosoftCopilot.ps1 -Mode Detect
# Exit 0 = COMPLIANT (Copilot nicht gefunden)
# Exit 1 = NON-COMPLIANT (Copilot gefunden)

# MODE: WDAC - Kernel-Ebene Blockierung (Enterprise)
.\Remove-MicrosoftCopilot.ps1 -Mode WDAC -AuditOnly  # Test-Modus
.\Remove-MicrosoftCopilot.ps1 -Mode WDAC -Deploy     # Produktiv
```

### Deployment

**Einzelne Workstation:**
```powershell
.\Remove-MicrosoftCopilot.ps1
```

**GPO (Startup Script):**
```
\\server\netlogon\Scripts\Remove-MicrosoftCopilot.ps1 -Force -NoRestart
```

**Intune (PowerShell Script):**
```
Install: powershell.exe -ExecutionPolicy Bypass -File "Remove-MicrosoftCopilot.ps1" -Force -NoRestart
Detect:  powershell.exe -ExecutionPolicy Bypass -File "Remove-MicrosoftCopilot.ps1" -Mode Detect
```

---

## Remove-CopilotComplete.ps1

**Hauptscript zur vollständigen Copilot-Entfernung**

### Features v2.1

**Neue Features:**
✅ **Copilot-Hardwaretaste blockieren** - Dedizierte Copilot-Taste umleiten
✅ **Windows Recall deaktivieren** - Screenshot-Aufzeichnung blockiert
✅ **Click-To-Do deaktivieren** - KI-Aktionen ausgeschaltet
✅ **Office Connected Experiences** - Cloudbasierte KI-Features deaktiviert
✅ **Game Bar Copilot** - Gaming-KI-Assistent entfernt
✅ **Erweiterte Domains** - Mehr Bing/Copilot-Endpunkte blockiert

**v2.0 Features:**
✅ **Rollback-Funktionalität** - Automatisches Backup aller Änderungen
✅ **Windows-Version-Erkennung** - Win10/Win11 spezifische Behandlung
✅ **Dynamische Pfaderkennung** - Keine hardcodierten Versionsnummern
✅ **AppLocker-Verbesserungen** - Prüfung vor Merge
✅ **Office-Versionserkennung** - Office 2013-2024 Support
✅ **Progress-Anzeige** - Besseres User-Feedback
✅ **JSON-Report** - Strukturiertes Logging

### 10-Phasen-Strategie

1. **App-Paket Entfernung** - AppX-Pakete & provisionierte Pakete
2. **Registry-Konfiguration** - Windows, Edge, Office, AI-Features
3. **Kontextmenü-Blockierung** - Shell Extension GUID
4. **AppLocker-Regeln** - Neuinstallation verhindern
5. **Firewall-Blockierung** - Domains + ausgehende Verbindungen
6. **Scheduled Tasks** - AI-Tasks deaktivieren
7. **Dienste-Management** - Übersprungen (Systemstabilität)
8. **GPO-Update** - Gruppenrichtlinien aktualisieren
9. **Verifizierung** - Automatische Überprüfung
10. **Bereinigung** - Explorer-Neustart & Cleanup

### Parameter

```powershell
Remove-CopilotComplete.ps1 [-LogOnly] [-NoRestart] [-NoBackup] [-Force] [-LogPath <path>]
```

### Beispiele

```powershell
# Testlauf ohne Änderungen
.\Remove-CopilotComplete.ps1 -LogOnly

# Produktiv mit Bestätigungsdialogen
.\Remove-CopilotComplete.ps1

# Automatisiert (GPO/Intune/SCCM)
.\Remove-CopilotComplete.ps1 -NoRestart -Force
```

### Backup & Rollback

**Backup-Verzeichnis:**
```
C:\Temp\CopilotRemoval_Backup_TIMESTAMP\
├── README.txt                 # Rollback-Anleitung
├── *.reg                      # Registry-Backups
├── AppLockerPolicy_Backup.xml # AppLocker-Backup
├── hosts.backup               # Hosts-Datei
└── ExecutionReport.json       # Detaillierter Report
```

**Rollback:** Doppelklick auf `.reg` Datei → Import bestätigen → Neustart

---

## Test-CopilotPresence.ps1

**Monitoring-Script für regelmäßige Überprüfung**

### Zweck

Prüft, ob Copilot nach Windows-Updates wieder erschienen ist.

### Überprüfungen

✅ App-Pakete (installiert & provisioniert)
✅ Registry-Einstellungen (HKLM & HKCU)
✅ Kontextmenü-Blockierung
✅ Hosts-Datei Einträge
✅ Firewall-Regeln
✅ Scheduled Tasks

### Parameter

```powershell
Test-CopilotPresence.ps1 [-EmailAlert <email>] [-SMTPServer <server>] [-CreateScheduledTask]
```

### Beispiele

```powershell
# Manuelle Überprüfung
.\Test-CopilotPresence.ps1

# Mit E-Mail-Benachrichtigung
.\Test-CopilotPresence.ps1 -EmailAlert admin@firma.de -SMTPServer mail.firma.de

# Monatlichen Scheduled Task erstellen
.\Test-CopilotPresence.ps1 -CreateScheduledTask
```

### Exit Codes

- **0** = Sauber - Kein Copilot gefunden
- **1** = Copilot gefunden - Aktion erforderlich
- **2** = Blockierungen unvollständig

---

## Detect-CopilotRemoval.ps1

**Detection Method für SCCM/Intune**

### Exit Codes

- **0** = COMPLIANT (Copilot nicht gefunden)
- **1** = NON-COMPLIANT (Copilot gefunden)

### Verwendung

**SCCM/ConfigMgr:**
- Detection Method → Use a custom script
- Script Type: PowerShell
- Script File: `Detect-CopilotRemoval.ps1`

**Microsoft Intune:**
- Detection rules → Use a custom detection script
- Script file: `Detect-CopilotRemoval.ps1`
- Run script as 32-bit: No

---

## Deployment-Strategien

### Option 1: Gruppenrichtlinie (GPO)
```
Computer Configuration → Policies → Windows Settings → Scripts → Startup
Script: Remove-CopilotComplete.ps1 -NoRestart -Force
```

### Option 2: Microsoft Intune
- App Type: Windows app (Win32)
- Install: `Remove-CopilotComplete.ps1 -NoRestart -Force`
- Detection: `Detect-CopilotRemoval.ps1`

### Option 3: SCCM/ConfigMgr
- Application → Script Installer
- Detection Method: Custom Script

### Option 4: Manuell
```powershell
# Test
.\Remove-CopilotComplete.ps1 -LogOnly

# Produktiv
.\Remove-CopilotComplete.ps1
```

📖 **[Detaillierte Deployment-Anleitung](DEPLOYMENT-GUIDE.md)**

---

## Projektstruktur

```
Ticket-25-695990-HIO-Copilot/
├── Remove-MicrosoftCopilot.ps1        # All-In-One Script (v2.1) ⭐
├── Remove-CopilotComplete.ps1       # Hauptscript (v2.1)
├── Test-CopilotPresence.ps1         # Monitoring-Script (v2.1)
├── Detect-CopilotRemoval.ps1        # SCCM/Intune Detection
├── Enable-WDACCopilotBlock.ps1      # WDAC Kernel-Blockierung
│
├── README.md                        # Diese Datei
├── DEPLOYMENT-GUIDE.md              # Vollständige Deployment-Dokumentation
├── LICENSE                          # MIT License
├── .gitignore                       # Git Ignore-Regeln
│
└── docs/                            # Dokumentation
    ├── copilot-removal-project.md   # Projekt-Dokumentation
    └── Zusätzliche Mechanismen....pdf # Technische Referenz
```

---

## Neue Features in v2.0

### Rollback-Funktionalität
- Automatisches Backup aller Registry-Änderungen
- `.reg` Dateien für einfachen Rollback
- Backup von Scheduled Tasks und Hosts-Datei

### Windows-Version-Erkennung
- Automatische Erkennung von Windows 10 vs 11
- Versionsspezifische Paketlisten
- Edition-Prüfung (Home/Pro/Enterprise)

### Dynamische Pfaderkennung
- Keine hardcodierten Versionsnummern
- Sucht Copilot.exe in allen relevanten Pfaden
- Zukunftssicher für Updates

### Verbesserte Fehlerbehandlung
- AppLocker-Prüfung vor Merge
- Regex-basierte Hosts-Datei Duplikat-Prüfung
- Explorer-Neustart mit Bestätigung

### Office-Versionserkennung
- Unterstützt Office 2013, 2016, 2019, 2021, 2024
- Automatische Erkennung installierter Versionen

### JSON-Report
- Strukturierter Execution Report
- Statistiken (Erfolge, Warnungen, Fehler)
- Maschinenlesbar für Automatisierung

---

## Systemanforderungen

- **Betriebssystem:** Windows 10 (Build 17763+) oder Windows 11
- **PowerShell:** Version 5.1 oder höher
- **Rechte:** Administratorrechte erforderlich
- **AppLocker:** Nur bei Windows Pro/Enterprise/Education

---

## Sicherheit & Compliance

✅ **Lizenzkonform** - Keine Verletzung von Microsoft-Lizenzbedingungen
✅ **DSGVO-konform** - Verhindert ungewollte Datenübertragung
✅ **Dokumentiert** - Alle Änderungen werden geloggt
✅ **Rollback** - Jederzeit rückgängig machbar

---

## 💬 Support & Contribution

Found a bug? Have a feature request? Please open an issue on GitHub!

Contributions are welcome! Please read the contribution guidelines before submitting pull requests.

---

## Changelog

### v2.1 (November 2025)
- ⭐ **Remove-MicrosoftCopilot.ps1**: All-In-One Script (4 Modi in 1 Datei)
- ✨ Copilot-Hardwaretaste blockieren/umleiten
- ✨ Windows Recall deaktivieren (Copilot+ PCs)
- ✨ Click-To-Do KI-Aktionen deaktivieren
- ✨ Office Connected Experiences komplett deaktivieren
- ✨ Game Bar Copilot entfernen
- ✨ Erweiterte Firewall-Domains (Bing-Endpunkte)
- ✨ WDAC-Support für Enterprise (Kernel-Ebene Blockierung)
- ✨ Test-CopilotPresence.ps1: Erweiterte Prüfungen

### v2.0 (November 2025)
- ✨ Rollback-Funktionalität
- ✨ Windows-Version-Erkennung
- ✨ Dynamische Pfaderkennung
- ✨ AppLocker-Verbesserungen
- ✨ Office-Versionserkennung
- ✨ Progress-Anzeige & JSON-Report
- 🐛 Zahlreiche Bugfixes
- 📚 Umfassende Dokumentation

### v1.0 (November 2025)
- Initial Release
- 10-Phasen-Strategie

---

**Status:** Production Ready
**Getestet auf:** Windows 10 22H2, Windows 11 24H2
**Letztes Update:** November 2025

---

## 👤 Author & Support

**Entwickelt von:**
Lars Bahlmann
badata GmbH - IT Systemhaus in Bremen
www.badata.de

**Kontakt:**
Für Support, Fragen oder Feature-Requests wenden Sie sich bitte an unser Support-Team.

**Lizenz:** MIT License
