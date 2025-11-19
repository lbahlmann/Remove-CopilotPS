# Microsoft Copilot Removal Toolkit v2.1.3

Vollständige Entfernung und Blockierung von Microsoft Copilot auf Windows 10/11 Systemen.

**Status:** ✅ Production Ready
**Version:** 2.1.3 (November 2025)
**License:** MIT

---

## 🆕 Neu in v2.1.3

✅ **Provisioned Package Removal** - Verhindert automatische Installation für neue Windows-User
✅ **Deprovisioned Registry Keys** - Blockiert Neuinstallation durch Feature Updates
✅ **Protocol Handler Blockierung** - ms-copilot:// und ms-windows-ai-copilot:// deaktiviert
✅ **Store Auto-Update Blockierung** - Verhindert Microsoft Store Reinstallation (Store bleibt funktional)
✅ **AppLocker Enhanced** - 5 Deny Rules (Publisher + Path Rules)

## Neu in v2.1.2

✅ **Microsoft 365 Copilot Blockierung** - Vollständige Deaktivierung in Word, Excel, PowerPoint, Outlook, OneNote
✅ **Per-Application Controls** - Granulare Kontrolle für jede Office-Anwendung
✅ **Enhanced Monitoring** - Test-Script prüft jetzt auch M365 Copilot-Einstellungen

## Neu in v2.1.1

✅ **Unattended-Modus** - Vollautomatisch für GPO/Intune/SCCM
✅ **RDS/Terminal Server Support** - UseTemp-Parameter für Multi-User-Umgebungen
✅ **Custom Backup-Verzeichnis** - BackupDir-Parameter für Netzwerk-Backups
✅ **Domain-Sicherheit** - NoGPUpdate-Parameter verhindert GPO-Überschreibung
✅ **Performance-Optimierung** - Registry-Operationen 75% schneller
✅ **33 Registry-Einstellungen** - Erweiterte Copilot-Blockierung (inkl. M365 Copilot)
✅ **6 DNS-Domains** - Gezielte Copilot-Domain-Blockierung

---

## 📋 Enthaltene Scripts

| Script | Zweck | Status |
|--------|-------|--------|
| **Remove-CopilotComplete.ps1** | Hauptscript zur Copilot-Entfernung | ✅ Produktiv |
| **Test-CopilotPresence.ps1** | Monitoring & Überprüfung | ✅ Produktiv |
| **Detect-CopilotRemoval.ps1** | Detection für SCCM/Intune | ✅ Produktiv |
| **Enable-WDACCopilotBlock.ps1** | WDAC Kernel-Blockierung (Optional) | ✅ Produktiv |
| **1-Run-CopilotRemoval-Test.cmd** | Starter-Script (Testmodus) | ✅ Produktiv |
| **2-Run-CopilotRemoval-Production.cmd** | Starter-Script (Produktiv) | ✅ Produktiv |

📖 **<a href="DEPLOYMENT-GUIDE.md" target="_blank">Vollständige Deployment-Dokumentation</a>**
📖 **<a href="GPO-DEPLOYMENT-GUIDE.md" target="_blank">GPO & Intune Deployment Guide</a>**

---

## 🚀 Schnellstart

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

## 💻 Remove-CopilotComplete.ps1

**Hauptscript zur vollständigen Copilot-Entfernung**

### 10-Phasen-Strategie

1. **App-Paket Entfernung** - AppX-Pakete (installiert & provisioniert)
2. **Deprovisioned Keys** - Feature Update Reinstallation Prevention ✨ NEU v2.1.3
3. **Registry-Konfiguration** - 33 Einstellungen (Windows, Edge, Office, M365 Copilot, AI-Features)
4. **Kontextmenü-Blockierung** - Shell Extension GUID blockieren
5. **AppLocker-Regeln** - 5 Deny Rules (Publisher + Path) ✨ NEU v2.1.3
6. **Protocol Handler** - ms-copilot:// blockiert ✨ NEU v2.1.3
7. **Store Auto-Update** - Copilot-Pakete blockiert ✨ NEU v2.1.3
8. **DNS-Blockierung** - 6 Copilot-Domains in hosts-Datei
9. **Scheduled Tasks** - AI-Tasks deaktivieren
10. **Firewall-Regeln** - Netzwerk-Blockierung

### Parameter

```powershell
Remove-CopilotComplete.ps1
    [-LogOnly]
    [-NoRestart]
    [-SkipBackup]
    [-Force]
    [-Unattended]
    [-UseTemp]
    [-BackupDir <path>]
    [-NoGPUpdate]
```

| Parameter | Beschreibung |
|-----------|--------------|
| `-LogOnly` | Testlauf ohne Änderungen (Dry-Run) |
| `-NoRestart` | Verhindert Neustart-Prompt und Explorer-Neustart |
| `-SkipBackup` | Überspringt Backup-Erstellung (nicht empfohlen) |
| `-Force` | Unterdrückt alle Bestätigungsdialoge |
| `-Unattended` | Vollautomatisch (impliziert -Force -NoRestart) |
| `-UseTemp` | Nutzt C:\Temp\CopilotRemoval\$env:USERNAME (RDS) |
| `-BackupDir` | Custom Backup-Pfad (z.B. Netzlaufwerk) |
| `-NoGPUpdate` | Überspringt gpupdate (verhindert Domain-GPO-Konflikte) |

### Verwendungsbeispiele

```powershell
# Testlauf ohne Änderungen
.\Remove-CopilotComplete.ps1 -LogOnly

# Produktiv mit Bestätigungsdialogen
.\Remove-CopilotComplete.ps1

# Automatisiert (GPO/Intune/SCCM)
.\Remove-CopilotComplete.ps1 -Unattended

# RDS/Terminal Server
.\Remove-CopilotComplete.ps1 -UseTemp -Unattended

# Domain-Computer (ohne GPO-Update)
.\Remove-CopilotComplete.ps1 -NoGPUpdate

# Custom Backup-Pfad
.\Remove-CopilotComplete.ps1 -BackupDir "\\server\backup\copilot"

# Vollautomatisch für GPO
.\Remove-CopilotComplete.ps1 -Unattended -NoGPUpdate
```

### Backup & Rollback

**Backup-Verzeichnis:**
```
$env:LOCALAPPDATA\CopilotRemoval\Backup_YYYYMMDD_HHMMSS\
├── Registry_*.reg              # Registry-Backups
├── hosts.backup                # Hosts-Datei
├── Report_YYYYMMDD_HHMMSS.json # Execution Report
└── Log_YYYYMMDD_HHMMSS.txt     # Detailliertes Log
```

**Rollback:** Doppelklick auf `.reg` Datei → Import bestätigen → Neustart

### Reinstallation Prevention (v2.1.3)

✅ **5 Schutz-Ebenen gegen Neuinstallation:**

1. **Provisioned Package Removal** - Entfernt AppX Provisioned Packages
2. **Deprovisioned Registry Keys** - Feature Update Reinstallation blockiert
3. **AppLocker Rules** - Application-Level Enforcement (5 Rules)
4. **Protocol Handler Blocking** - ms-copilot:// deaktiviert
5. **Store Auto-Update Blocking** - Microsoft Store Reinstallation verhindert

### Features v2.1.3

✨ **Provisioned Package Removal** - 5 Package Family Names deprovisioned
✨ **Deprovisioned Registry Keys** - HKLM:\\...\\Appx\\AppxAllUserStore\\Deprovisioned
✨ **Protocol Handler Blockierung** - 3 Handler (ms-copilot, microsoft-edge-holographic, ms-windows-ai-copilot)
✨ **Store Auto-Update Blockierung** - BlockedPackages Registry (Store bleibt funktional!)
✨ **AppLocker Enhanced** - 3x FilePublisher + 2x FilePath Rules

### Features v2.1.2

✅ **Microsoft 365 Copilot** - Vollständig blockiert in Word, Excel, PowerPoint, Outlook, OneNote
✅ **Copilot-Hardwaretaste blockieren** - Dedizierte Copilot-Taste umleitet
✅ **Windows Recall deaktivieren** - Screenshot-Aufzeichnung blockiert
✅ **Click-To-Do deaktivieren** - KI-Aktionen ausgeschaltet
✅ **Office Connected Experiences** - Cloud-KI-Features deaktiviert
✅ **Game Bar Copilot** - Gaming-KI-Assistent entfernt
✅ **Edge Copilot** - Browser-Integration blockiert
✅ **Notepad/Paint Copilot** - App-spezifische KI deaktiviert

---

## 🔍 Test-CopilotPresence.ps1

**Monitoring-Script für regelmäßige Überprüfung**

### Überprüfungen

✅ App-Pakete (installiert & provisioniert)
✅ Registry-Einstellungen (HKLM & HKCU, inkl. v2.1.2/2.1.3 Features)
✅ Kontextmenü-Blockierung
✅ Hosts-Datei Einträge
✅ Firewall-Regeln
✅ Scheduled Tasks
✅ Office Connected Experiences
✅ **Microsoft 365 Copilot** (Word, Excel, PowerPoint, Outlook, OneNote)
✅ **Deprovisioned Keys** ✨ NEU v2.1.3
✅ **Protocol Handler** ✨ NEU v2.1.3

### Parameter

```powershell
Test-CopilotPresence.ps1
    [-EmailAlert <email>]
    [-SMTPServer <server>]
    [-CreateScheduledTask]
    [-LogPath <path>]
    [-UseTemp]
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

## 🎯 Detect-CopilotRemoval.ps1

**Detection Method für SCCM/Intune**

### Exit Codes

- **0** = COMPLIANT (Copilot nicht gefunden)
- **1** = NON-COMPLIANT (Copilot gefunden oder Blockierungen fehlen)

### Verwendung

**Microsoft Intune:**
- Detection rules → Use a custom detection script
- Script file: `Detect-CopilotRemoval.ps1`
- Run script as 32-bit: No

**SCCM/ConfigMgr:**
- Detection Method → Use a custom script
- Script Type: PowerShell
- Script File: `Detect-CopilotRemoval.ps1`

---

## 🛡️ Enable-WDACCopilotBlock.ps1

**WDAC Kernel-Ebene Blockierung (Optional, Enterprise)**

### Parameter

```powershell
Enable-WDACCopilotBlock.ps1
    [-PolicyPath <path>]
    [-Deploy]
    [-AuditOnly]
```

### Beispiele

```powershell
# Policy erstellen (ohne Deployment)
.\Enable-WDACCopilotBlock.ps1

# Audit-Modus (nur Logging, kein Blocking)
.\Enable-WDACCopilotBlock.ps1 -AuditOnly -Deploy

# Produktiv deployen
.\Enable-WDACCopilotBlock.ps1 -Deploy
```

⚠️ **Hinweis:** WDAC ist sehr restriktiv - nur für Enterprise mit Tests in VM!

---

## 📦 Deployment-Strategien

### Option 1: Gruppenrichtlinie (GPO)

```
Computer Configuration → Policies → Windows Settings → Scripts → Startup
Script: Remove-CopilotComplete.ps1 -Unattended -NoGPUpdate
```

### Option 2: Microsoft Intune

```
App Type: Windows app (Win32)
Install: powershell.exe -ExecutionPolicy Bypass -File "Remove-CopilotComplete.ps1" -Unattended
Detect:  Detect-CopilotRemoval.ps1
```

### Option 3: SCCM/ConfigMgr

```
Application → Script Installer
Install: Remove-CopilotComplete.ps1 -Unattended -NoGPUpdate
Detection: Detect-CopilotRemoval.ps1
```

### Option 4: Manuell

```powershell
# CMD-Starter (Admin-Rechte + Testmodus)
1-Run-CopilotRemoval-Test.cmd

# CMD-Starter (Admin-Rechte + Produktiv)
2-Run-CopilotRemoval-Production.cmd
```

📖 **<a href="DEPLOYMENT-GUIDE.md" target="_blank">Detaillierte Deployment-Anleitung</a>**
📖 **<a href="GPO-DEPLOYMENT-GUIDE.md" target="_blank">GPO & Intune Deployment Guide</a>**

---

## 📁 Projektstruktur

```
copilot-removal-toolkit/
├── Remove-CopilotComplete.ps1          # Main script v2.1.3
├── Test-CopilotPresence.ps1            # Monitoring script v1.1
├── Detect-CopilotRemoval.ps1           # SCCM/Intune detection v1.1
├── Enable-WDACCopilotBlock.ps1         # WDAC blocking v1.0
├── 1-Run-CopilotRemoval-Test.cmd       # Starter (test mode)
├── 2-Run-CopilotRemoval-Production.cmd # Starter (production)
├── README.md                           # This file
├── DEPLOYMENT-GUIDE.md                 # Deployment guide
├── GPO-DEPLOYMENT-GUIDE.md             # GPO/Intune guide
├── LICENSE                             # MIT License
└── .gitignore                          # Git ignore rules
```

---

## ⚙️ Systemanforderungen

- **Betriebssystem:** Windows 10 (Build 17763+) oder Windows 11
- **PowerShell:** Version 5.1 oder höher
- **Rechte:** Administratorrechte erforderlich
- **AppLocker:** Nur bei Windows Pro/Enterprise/Education
- **WDAC:** Nur bei Windows Enterprise/Education/Server

---

## 🔒 Sicherheit & Compliance

✅ **Lizenzkonform** - Keine Verletzung von Microsoft-Lizenzbedingungen
✅ **DSGVO-konform** - Verhindert ungewollte Datenübertragung
✅ **Dokumentiert** - Alle Änderungen werden geloggt
✅ **Rollback** - Jederzeit rückgängig machbar
✅ **Getestet** - Windows 10 22H2, Windows 11 24H2, Windows 11 Build 26200

---

## 📖 Offizielle Microsoft-Dokumentation

**Windows Copilot:**
- <a href="https://learn.microsoft.com/en-us/windows/client-management/manage-windows-copilot" target="_blank">Microsoft Learn - Manage Windows Copilot</a>
- <a href="https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowsai" target="_blank">Microsoft Learn - WindowsAI Policy CSP</a>

**AppLocker:**
- <a href="https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/create-a-rule-for-packaged-apps" target="_blank">Microsoft Learn - Create a rule for packaged apps</a>
- <a href="https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/manage-packaged-apps-with-applocker" target="_blank">Microsoft Learn - Manage packaged apps with AppLocker</a>

**Microsoft 365 Copilot:**
- <a href="https://support.microsoft.com/en-us/office/turn-off-copilot-in-microsoft-365-apps-bc7e530b-152d-4123-8e78-edc06f8b85f1" target="_blank">Microsoft Support - Turn off Copilot in M365 Apps</a>
- <a href="https://learn.microsoft.com/en-us/copilot/microsoft-365/microsoft-365-copilot-app-admin-settings" target="_blank">Microsoft Learn - M365 Copilot app settings for IT admins</a>

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
- 📊 Phase 4b: Block-CopilotProtocolHandlers() - HKCR Registry
- 📊 Phase 4c: Block-CopilotStoreAutoUpdate() - BlockedPackages Registry
- 🐛 Hotfix 1: HKCR PSDrive creation (verhindert "Laufwerk nicht gefunden" Fehler)

**Statistik:**
- +250 Zeilen Code
- 3 neue Funktionen
- 3 neue Phasen (1b, 4b, 4c)
- 5 Reinstallations-Vektoren blockiert

### v2.1.2 (November 2025)

**Neue Features:**
- ✨ **Microsoft 365 Copilot Blockierung** - Vollständige Deaktivierung in Office-Anwendungen
- ✨ **13 neue Registry-Einstellungen** - M365 Copilot für Word, Excel, PowerPoint, Outlook, OneNote
- ✨ **Enhanced Monitoring** - Test-CopilotPresence.ps1 prüft M365 Copilot-Status
- ✨ **Per-Application Controls** - Granulare Kontrolle pro Office-App

**Technische Details:**
- 📊 Gesamt: 33 Registry-Einstellungen (vorher 20)
- 🔒 M365 Copilot: Main Toggle (HKCU/HKLM) + Per-App Settings
- ✅ Test-Script: Neue Funktion Test-Microsoft365Copilot()

### v2.1.1 (November 2025)

**Neue Features:**
- ✨ **Unattended-Modus** - Vollautomatischer Betrieb für GPO/Intune/SCCM
- ✨ **RDS/Terminal Server Support** - UseTemp-Parameter für Multi-User
- ✨ **Domain-Sicherheit** - NoGPUpdate-Parameter verhindert GPO-Konflikte
- ✨ **Custom Backup Directory** - BackupDir-Parameter für Netzwerk-Backups
- ✨ **Performance-Optimierung** - Registry-Backup 75% schneller
- ✨ **Progress Bar Fix** - Kein Flackern mehr (Update alle 5 Keys)

**Bugfixes:**
- 🐛 **Encoding-Fix** - PowerShell UTF-8 Parsing-Probleme behoben
- 🐛 **Test-CopilotPresence.ps1** - Unicode-Zeichen durch ASCII ersetzt
- 🐛 **Enable-WDACCopilotBlock.ps1** - Deny-Regeln werden jetzt korrekt eingefügt
- 🐛 **JSON-Serialization** - Vereinfachtes Report-Objekt verhindert Hanging

**Code-Qualität:**
- ✅ Alle Scripts Syntax-validiert (0 Fehler)
- ✅ Logik-Fehler behoben
- ✅ Production-Ready

### v2.1 (November 2025)

- ✨ Copilot-Hardwaretaste blockieren/umleiten
- ✨ Windows Recall deaktivieren (Copilot+ PCs)
- ✨ Click-To-Do KI-Aktionen deaktivieren
- ✨ Office Connected Experiences komplett deaktivieren
- ✨ Game Bar Copilot entfernen
- ✨ Edge/Notepad/Paint Copilot blockieren
- ✨ 20 Registry-Einstellungen (erweitert von 6)
- ✨ 6 DNS-Domains gezielt blockiert

### v2.0 (November 2025)

- ✨ Rollback-Funktionalität
- ✨ Windows-Version-Erkennung
- ✨ Dynamische Pfaderkennung
- ✨ JSON-Report
- ✨ Progress-Anzeige

### v1.0 (November 2025)

- Initial Release

---

## 📄 License & Documentation

**License:** MIT License

**Documentation:**
- <a href="README.md" target="_blank">README.md</a> - This file
- <a href="DEPLOYMENT-GUIDE.md" target="_blank">DEPLOYMENT-GUIDE.md</a> - Deployment guide
- <a href="GPO-DEPLOYMENT-GUIDE.md" target="_blank">GPO-DEPLOYMENT-GUIDE.md</a> - GPO/Intune guide

---

**Letztes Update:** November 2025 (v2.1.3)
**Status:** ✅ Production Ready
**Getestet auf:** Windows 10 22H2, Windows 11 24H2, Windows 11 Build 26200
**Neu:** Reinstallation Prevention (5 Schutz-Ebenen)
