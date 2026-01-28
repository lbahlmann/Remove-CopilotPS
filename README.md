# Microsoft Copilot Removal Toolkit v2.3.1

Vollständige Entfernung und Blockierung von Microsoft Copilot auf Windows 10/11 Systemen.

**Status:** ✅ Production Ready
**Version:** 2.3.1 (Januar 2026)
**License:** MIT

---

## 🆕 Neu in v2.3.1 (basierend auf Online-Recherche)

✅ **EnableAppsInOutlook=0** - **KRITISCH**: Entfernt Copilot-Button komplett aus Classic Outlook
✅ **EdgeEntraCopilotPageContext** - Ersetzt veraltetes CopilotCDPPageContext (deprecated ab Edge 133)
✅ **EdgeSidebarAppUrlHostBlockList** - Granulare URL-Blockierung für edge://discover-chat
✅ **EdgeSidebarCustomizeEnabled=0** - Verhindert Benutzeranpassung der Sidebar
✅ **EdgeOpenInSidebarEnabled=0** - Deaktiviert "In Sidebar öffnen" Option
✅ **StandaloneHubsSidebarEnabled=0** - Zusätzliche Sidebar-Blockierung
✅ **4 Copilot-URLs blockiert** - edge://discover-chat, edge://discover, copilot.microsoft.com, bing.com/chat

## Neu in v2.3.0

✅ **Outlook COM Add-In Deaktivierung** - Blockiert Copilot-Button in Classic Outlook (Phase 4d)
✅ **Edge Copilot Extension Blockierung** - Blockiert Copilot-Extensions und Sidebar-Icon (Phase 4e)
✅ **Erweiterte Edge Registry-Settings** - 7 zusätzliche Edge-Policies für vollständige Blockierung
✅ **Policy-basierte Outlook-Blockierung** - DoNotLoadAddinList für zuverlässige Add-In-Deaktivierung
✅ **HKU-Iteration für Add-Ins** - Deaktiviert Outlook Add-Ins für alle User-Profile

## Neu in v2.2.1 (Hotfix)

🐛 **Self-Sabotage Bug behoben** - Phase 6 deaktiviert nicht mehr den eigenen "Copilot-Removal" Task
🐛 **Task-Erstellung robuster** - Verwendet jetzt direkt schtasks.exe mit XML (statt PowerShell Register-ScheduledTask)
🐛 **GPO-Deployment** - `-Unattended` Parameter in Deploy-CopilotRemoval.cmd hinzugefügt
🐛 **Versions-Tracking** - Script überprüft Version vor erneuter Ausführung (verhindert 33x Ausführung bei GPO)
🐛 **Backup/Log-Pfade vereinheitlicht** - Beide unter `C:\ProgramData\badata\CopilotRemoval\`

## Neu in v2.2

✅ **Self-Elevation (UAC)** - Automatischer Admin-Prompt für Non-Admin User
✅ **Phase 0: Prozess-Beendigung** - Copilot-Prozesse werden vor Entfernung beendet
✅ **Zentrale Log-Location** - `C:\ProgramData\badata\CopilotRemoval\Logs\` mit User-Kontext
✅ **HKU-Iteration** - Registry-Änderungen für alle User-Profile (nicht nur HKCU)
✅ **Scheduled Task Support** - Automatische Wartung mit `-CreateScheduledTask`
✅ **WebExperience Pattern** - MicrosoftWindows.Client.WebExperience wird erkannt
✅ **MicrosoftOfficeHub Pattern** - "Microsoft 365 Copilot" App wird entfernt
✅ **AppLocker Enhanced** - 7 Deny Rules (vorher 5)
✅ **Task-Persistenz** - schtasks.exe Fallback für zuverlässige Task-Erstellung
✅ **CMD-Wrapper** - Deploy-CopilotRemoval.cmd für einfaches Deployment

## Neu in v2.1.3

✅ **Provisioned Package Removal** - Verhindert automatische Installation für neue Windows-User
✅ **Deprovisioned Registry Keys** - Blockiert Neuinstallation durch Feature Updates
✅ **Protocol Handler Blockierung** - ms-copilot:// und ms-windows-ai-copilot:// deaktiviert
✅ **Store Auto-Update Blockierung** - Verhindert Microsoft Store Reinstallation (Store bleibt funktional)

## Neu in v2.1.2

✅ **Microsoft 365 Copilot Blockierung** - Vollständige Deaktivierung in Word, Excel, PowerPoint, Outlook, OneNote
✅ **Per-Application Controls** - Granulare Kontrolle für jede Office-Anwendung
✅ **Enhanced Monitoring** - Test-Script prüft jetzt auch M365 Copilot-Einstellungen

---

## 📋 Enthaltene Scripts

| Script | Zweck | Status |
|--------|-------|--------|
| **Remove-CopilotComplete.ps1** | Hauptscript zur Copilot-Entfernung | ✅ Produktiv |
| **Test-CopilotPresence.ps1** | Monitoring & Überprüfung | ✅ Produktiv |
| **Detect-CopilotRemoval.ps1** | Detection für SCCM/Intune | ✅ Produktiv |
| **Enable-WDACCopilotBlock.ps1** | WDAC Kernel-Blockierung (Optional) | ✅ Produktiv |
| **Deploy-CopilotRemoval.cmd** | CMD-Wrapper für Deployment | ✅ NEU v2.2 |
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

### 3. Mit Scheduled Task (empfohlen)

```powershell
.\Remove-CopilotComplete.ps1 -CreateScheduledTask -TaskSchedule Weekly
```

### 4. Monitoring einrichten

```powershell
.\Test-CopilotPresence.ps1 -CreateScheduledTask
```

---

## 💻 Remove-CopilotComplete.ps1

**Hauptscript zur vollständigen Copilot-Entfernung**

### 13-Phasen-Strategie (v2.3)

0. **Prozess-Beendigung** - Copilot-Prozesse werden beendet
1. **App-Paket Entfernung** - AppX-Pakete (installiert & provisioniert)
1b. **Deprovisioned Keys** - Feature Update Reinstallation Prevention
2. **Registry-Konfiguration** - 44 Einstellungen (Windows, Edge, Office, M365 Copilot, AI-Features) ✨ ENHANCED v2.3
3. **Kontextmenü-Blockierung** - Shell Extension GUID blockieren
4. **AppLocker-Regeln** - 7 Deny Rules (Publisher + Path)
4b. **Protocol Handler** - ms-copilot:// blockiert
4c. **Store Auto-Update** - Copilot-Pakete blockiert
4d. **Outlook Add-In Deaktivierung** ✨ NEU v2.3 - COM Add-Ins in Classic Outlook
4e. **Edge Extension Blockierung** ✨ NEU v2.3 - Copilot-Extensions und Sidebar
5. **DNS-Blockierung** - 6 Copilot-Domains in hosts-Datei
6. **Scheduled Tasks** - AI-Tasks deaktivieren
7-10. **Firewall & Reporting** - Netzwerk-Blockierung, Logs, Reports

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
    [-CreateScheduledTask]    # NEU v2.2
    [-TaskSchedule <Daily|Weekly|Monthly>]  # NEU v2.2
    [-WithReboot]             # NEU v2.2
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
| `-CreateScheduledTask` | ✨ NEU: Erstellt Scheduled Task für automatische Wartung |
| `-TaskSchedule` | ✨ NEU: Task-Intervall (Daily/Weekly/Monthly, Standard: Weekly) |
| `-WithReboot` | ✨ NEU: Automatischer Reboot nach Ausführung |

### Verwendungsbeispiele

```powershell
# Testlauf ohne Änderungen
.\Remove-CopilotComplete.ps1 -LogOnly

# Produktiv mit Bestätigungsdialogen
.\Remove-CopilotComplete.ps1

# Mit wöchentlichem Scheduled Task (empfohlen)
.\Remove-CopilotComplete.ps1 -CreateScheduledTask -TaskSchedule Weekly

# Automatisiert (GPO/Intune/SCCM)
.\Remove-CopilotComplete.ps1 -Unattended

# RDS/Terminal Server
.\Remove-CopilotComplete.ps1 -UseTemp -Unattended

# Domain-Computer (ohne GPO-Update)
.\Remove-CopilotComplete.ps1 -NoGPUpdate

# Custom Backup-Pfad
.\Remove-CopilotComplete.ps1 -BackupDir "\\server\backup\copilot"

# Vollautomatisch mit Task und Reboot
.\Remove-CopilotComplete.ps1 -Unattended -CreateScheduledTask -WithReboot
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

**Zentrale Logs (v2.2):**
```
C:\ProgramData\badata\CopilotRemoval\Logs\
├── Log_YYYYMMDD_HHMMSS_User-<Username>.txt    # User-Ausführung
└── Log_YYYYMMDD_HHMMSS_SYSTEM-Task.txt        # Scheduled Task
```

**Rollback:** Doppelklick auf `.reg` Datei → Import bestätigen → Neustart

### Reinstallation Prevention (v2.2)

✅ **5 Schutz-Ebenen gegen Neuinstallation:**

1. **Provisioned Package Removal** - Entfernt AppX Provisioned Packages
2. **Deprovisioned Registry Keys** - Feature Update Reinstallation blockiert
3. **AppLocker Rules** - Application-Level Enforcement (7 Rules)
4. **Protocol Handler Blocking** - ms-copilot:// deaktiviert
5. **Store Auto-Update Blocking** - Microsoft Store Reinstallation verhindert

### Package Family Names v2.2 (6)

```
Microsoft.Copilot_8wekyb3d8bbwe
Microsoft.Windows.Ai.Copilot.Provider_8wekyb3d8bbwe
MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy
Microsoft.WindowsCopilot_8wekyb3d8bbwe
Microsoft.Windows.Copilot_8wekyb3d8bbwe
Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe  ← NEU v2.2
```

### Features v2.3.1

✨ **EnableAppsInOutlook=0** - KRITISCH: Entfernt Copilot-Button komplett aus Classic Outlook
✨ **EdgeEntraCopilotPageContext** - Moderne Policy (ersetzt veraltetes CopilotCDPPageContext)
✨ **EdgeSidebarAppUrlHostBlockList** - Granulare Blockierung von Copilot-URLs in Sidebar
✨ **EdgeSidebarCustomizeEnabled=0** - Verhindert Sidebar-Anpassung durch Benutzer
✨ **EdgeOpenInSidebarEnabled=0** - Deaktiviert "In Sidebar öffnen" Kontextmenü
✨ **48 Registry-Einstellungen** - (vorher 44, +4 für Edge/Outlook)

### Features v2.3

✨ **Outlook COM Add-In Deaktivierung** - Disable-OutlookCopilotAddIn() deaktiviert Copilot in Classic Outlook
✨ **Edge Extension Blockierung** - Block-EdgeCopilotExtensions() blockiert Copilot-Extensions
✨ **7 zusätzliche Edge Registry-Settings** - DiscoverPageContextEnabled, Sidebar-Settings
✨ **4 neue Outlook Policy-Settings** - DisableCopilot, DisableCopilotInOutlook für HKLM/HKCU
✨ **Policy-basierte Add-In-Blockierung** - DoNotLoadAddinList für Enterprise-Kontrolle
✨ **HKU-Iteration für Outlook** - Add-Ins werden für alle User-Profile deaktiviert

### Features v2.2

✨ **Self-Elevation (UAC)** - Non-Admin User erhalten automatisch UAC-Prompt
✨ **Phase 0: Prozess-Beendigung** - Stop-CopilotProcesses beendet laufende Copilot-Prozesse
✨ **HKU-Iteration** - Set-RegistryForAllUsers schreibt in alle User-Profile
✨ **Zentrale Logs** - C:\ProgramData\badata\CopilotRemoval\Logs\ mit Kontext
✨ **Scheduled Task** - Automatische Wartung mit AtStartup + Weekly Trigger
✨ **WebExperience** - MicrosoftWindows.Client.WebExperience wird erkannt
✨ **MicrosoftOfficeHub** - "Microsoft 365 Copilot" App wird entfernt
✨ **AppLocker Enhanced** - 7 Deny Rules (5x Publisher + 2x Path)
✨ **Task-Persistenz** - schtasks.exe Fallback mit XML-Datei
✨ **Sicherer Speicherort** - C:\Program Files\badata\CopilotRemoval\

### Features v2.1.3

✅ **Provisioned Package Removal** - 5 Package Family Names deprovisioned
✅ **Deprovisioned Registry Keys** - HKLM:\...\Appx\AppxAllUserStore\Deprovisioned
✅ **Protocol Handler Blockierung** - 3 Handler (ms-copilot, microsoft-edge-holographic, ms-windows-ai-copilot)
✅ **Store Auto-Update Blockierung** - BlockedPackages Registry (Store bleibt funktional!)
✅ **AppLocker Enhanced** - 3x FilePublisher + 2x FilePath Rules (jetzt 7 in v2.2)

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
✅ Registry-Einstellungen (HKLM & HKCU, inkl. v2.2 Features)
✅ Kontextmenü-Blockierung
✅ Hosts-Datei Einträge
✅ Firewall-Regeln
✅ Scheduled Tasks
✅ Office Connected Experiences
✅ **Microsoft 365 Copilot** (Word, Excel, PowerPoint, Outlook, OneNote)
✅ **Deprovisioned Keys**
✅ **Protocol Handler**

### Parameter

```powershell
Test-CopilotPresence.ps1
    [-EmailAlert <email>]
    [-SMTPServer <server>]
    [-CreateScheduledTask]
    [-LogPath <path>]
    [-UseTemp]
    [-Force]      # NEU: Überspringt Bestätigung
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
Script: Remove-CopilotComplete.ps1 -Unattended -NoGPUpdate -CreateScheduledTask
```

### Option 2: Microsoft Intune

```
App Type: Windows app (Win32)
Install: powershell.exe -ExecutionPolicy Bypass -File "Remove-CopilotComplete.ps1" -Unattended -CreateScheduledTask
Detect:  Detect-CopilotRemoval.ps1
```

### Option 3: SCCM/ConfigMgr

```
Application → Script Installer
Install: Remove-CopilotComplete.ps1 -Unattended -NoGPUpdate -CreateScheduledTask
Detection: Detect-CopilotRemoval.ps1
```

### Option 4: CMD-Wrapper (NEU v2.2)

```cmd
Deploy-CopilotRemoval.cmd
```

### Option 5: Manuell

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
├── Remove-CopilotComplete.ps1          # Main script v2.2
├── Test-CopilotPresence.ps1            # Monitoring script v1.1
├── Detect-CopilotRemoval.ps1           # SCCM/Intune detection v1.1
├── Enable-WDACCopilotBlock.ps1         # WDAC blocking v1.0
├── Deploy-CopilotRemoval.cmd           # CMD-Wrapper v2.2 (NEU)
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
- **Rechte:** Administratorrechte erforderlich (Self-Elevation in v2.2)
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

### v2.3.1 (Januar 2026) - Current

**Basierend auf Online-Recherche (Microsoft Learn, Community-Feedback):**
- ✨ **EnableAppsInOutlook=0** - KRITISCH: Entfernt Copilot-Button komplett aus Classic Outlook
- ✨ **EdgeEntraCopilotPageContext** - Ersetzt veraltetes CopilotCDPPageContext (deprecated ab Edge 133)
- ✨ **EdgeSidebarAppUrlHostBlockList** - Granulare URL-Blockierung (edge://discover-chat, edge://discover, etc.)
- ✨ **EdgeSidebarCustomizeEnabled=0** - Verhindert Benutzeranpassung der Sidebar
- ✨ **EdgeOpenInSidebarEnabled=0** - Deaktiviert "In Sidebar öffnen" Option
- ✨ **StandaloneHubsSidebarEnabled=0** - Zusätzliche Sidebar-Blockierung

**Technische Details:**
- 📊 48 Registry-Einstellungen (vorher 44)
- 📊 4 Copilot-URLs in EdgeSidebarAppUrlHostBlockList blockiert
- 📊 Veraltete Policy CopilotCDPPageContext durch EdgeEntraCopilotPageContext ersetzt

**Quellen:**
- [Microsoft Learn - EdgeSidebarAppUrlHostBlockList](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-browser-policies/edgesidebarappurlhostblocklist)
- [Microsoft Learn - EdgeEntraCopilotPageContext](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-browser-policies/edgeentracopilotpagecontext)
- [Microsoft Q&A - Show Apps in Outlook](https://learn.microsoft.com/en-us/answers/questions/1347973/how-to-turn-off-show-apps-in-outlook-via-gpo)

### v2.3.0 (Januar 2026)

**Neue Features:**
- ✨ **Outlook COM Add-In Deaktivierung** (Phase 4d) - Blockiert Copilot-Button in Classic Outlook
- ✨ **Edge Copilot Extension Blockierung** (Phase 4e) - Blockiert Copilot-Extensions und Sidebar-Icon
- ✨ **7 zusätzliche Edge Registry-Settings** - DiscoverPageContextEnabled, ShowRecommendationsEnabled, etc.
- ✨ **4 neue Outlook Policy-Settings** - DisableCopilot und DisableCopilotInOutlook für HKLM und HKCU
- ✨ **Policy-basierte Add-In-Blockierung** - DoNotLoadAddinList mit AddinListEnabled für Enterprise-Kontrolle
- ✨ **HKU-Iteration für Outlook Add-Ins** - Deaktiviert Add-Ins für alle User-Profile

**Technische Details:**
- 📊 Phase 4d: Disable-OutlookCopilotAddIn() - COM Add-In Deaktivierung via LoadBehavior=0
- 📊 Phase 4e: Block-EdgeCopilotExtensions() - Extension-Blocklist und Sidebar-Settings
- 📊 44 Registry-Einstellungen (vorher 33)
- 📊 5 bekannte Copilot Add-In ProgIDs werden blockiert
- 📊 3 Edge Extension IDs werden blockiert

**Behobene Probleme aus Kundenfeedback:**
- 🐛 Copilot-Button in Outlook-Toolbar (Classic Outlook)
- 🐛 Copilot-Icon in Edge-Browser oben rechts

### v2.2.1 (Dezember 2025) - Hotfix

**Bugfixes:**
- 🐛 **Self-Sabotage Bug** - Phase 6 deaktiviert nicht mehr den eigenen "Copilot-Removal" Task
- 🐛 **Task-Erstellung** - Verwendet jetzt direkt schtasks.exe mit XML (PowerShell Register-ScheduledTask erstellt Tasks als disabled)
- 🐛 **GPO-Deployment** - `-Unattended` Parameter in Deploy-CopilotRemoval.cmd hinzugefügt
- 🐛 **Versions-Tracking** - Script prüft Version vor erneuter Ausführung (verhindert 33x Ausführung bei GPO)
- 🐛 **Backup/Log-Pfade** - Vereinheitlicht unter `C:\ProgramData\badata\CopilotRemoval\`
- 🐛 **$ExecutionContext** - Umbenannt zu $RunContext (reservierte PowerShell-Variable)
- 🐛 **WebViewHost** - Microsoft 365 Copilot App Prozess wird jetzt erkannt und beendet

### v2.2 (Dezember 2025)

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
- ✨ **Sicherer Speicherort** - C:\Program Files\badata\CopilotRemoval\ für Script-Kopie

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
- 📊 Phase 4b: Block-CopilotProtocolHandlers() - HKCR Registry
- 📊 Phase 4c: Block-CopilotStoreAutoUpdate() - BlockedPackages Registry
- 🐛 Hotfix 1: HKCR PSDrive creation (verhindert "Laufwerk nicht gefunden" Fehler)

### v2.1.2 (November 2025)

**Neue Features:**
- ✨ **Microsoft 365 Copilot Blockierung** - Vollständige Deaktivierung in Office-Anwendungen
- ✨ **13 neue Registry-Einstellungen** - M365 Copilot für Word, Excel, PowerPoint, Outlook, OneNote
- ✨ **Enhanced Monitoring** - Test-CopilotPresence.ps1 prüft M365 Copilot-Status
- ✨ **Per-Application Controls** - Granulare Kontrolle pro Office-App

### v2.1.1 (November 2025)

**Neue Features:**
- ✨ **Unattended-Modus** - Vollautomatischer Betrieb für GPO/Intune/SCCM
- ✨ **RDS/Terminal Server Support** - UseTemp-Parameter für Multi-User
- ✨ **Domain-Sicherheit** - NoGPUpdate-Parameter verhindert GPO-Konflikte
- ✨ **Custom Backup Directory** - BackupDir-Parameter für Netzwerk-Backups
- ✨ **Performance-Optimierung** - Registry-Backup 75% schneller

### v2.1 (November 2025)

- ✨ Copilot-Hardwaretaste blockieren/umleiten
- ✨ Windows Recall deaktivieren (Copilot+ PCs)
- ✨ 20 Registry-Einstellungen
- ✨ 6 DNS-Domains gezielt blockiert

### v2.0 (November 2025)

- ✨ Rollback-Funktionalität
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

**Letztes Update:** Januar 2026 (v2.3.1)
**Status:** ✅ Production Ready
**Getestet auf:** Windows 10 22H2, Windows 11 24H2, Windows 11 Build 26100
**Neu:** EnableAppsInOutlook, EdgeSidebarAppUrlHostBlockList, EdgeEntraCopilotPageContext
