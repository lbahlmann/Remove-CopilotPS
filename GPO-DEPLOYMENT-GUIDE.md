##### Group Policy Deployment Guide - Microsoft Copilot Blockierung

**Version:** 1.0
**Datum:** 19. November 2025
**Zielgruppe:** IT-Administratoren, System Engineers
**Gültigkeit:** Windows 10/11, Microsoft 365 Apps

---

##### 📋 Inhaltsverzeichnis

1. [Übersicht](#übersicht)
2. [Script vs. Manuelle Konfiguration](#script-vs-manuelle-konfiguration)
3. [Windows Copilot Blockierung](#windows-copilot-blockierung)
4. [Microsoft 365 Copilot Blockierung](#microsoft-365-copilot-blockierung)
5. [ADMX/ADML Templates](#admxadml-templates)
6. [AppLocker-Konfiguration](#applocker-konfiguration)
7. [Intune/MDM-Konfiguration](#intunemdm-konfiguration)
8. [Verifikation](#verifikation)
9. [Quellen](#quellen)

---

##### Übersicht

Dieses Dokument beschreibt die **offizielle Microsoft-empfohlene Methode** zur Blockierung von Windows Copilot und Microsoft 365 Copilot über Group Policy Objects (GPO), Intune und Registry-Einstellungen.

##### ⚠️ Wichtige Hinweise

- Die **"Turn Off Windows Copilot"** Legacy-Policy wird von Microsoft **depreciert** (<a href="https://learn.microsoft.com/en-us/windows/client-management/manage-windows-copilot" target="_blank">Quelle</a>)
- **AppLocker** ist die **empfohlene Methode** für Windows 11 24H2/2025 und neuere Builds
- Registry-Keys sollten nur als **Fallback** verwendet werden

---

##### Script vs. Manuelle Konfiguration

##### 🤖 Was erledigt `Remove-CopilotComplete.ps1` automatisch?

Das PowerShell-Script **Remove-CopilotComplete.ps1** implementiert folgende Maßnahmen **automatisch**:

| Feature | Methode | Script-Phase | Status |
|---------|---------|--------------|--------|
| **Copilot-Paket entfernen** | `Remove-AppxPackage -AllUsers` | Phase 1 | ✅ Automatisch |
| **Provisioned Packages entfernen** | `Remove-AppxProvisionedPackage` | Phase 1 | ✅ Automatisch |
| **Deprovisioned Registry Keys** | Registry (HKLM) | Phase 1b | ✅ Automatisch |
| **Windows Copilot Registry** | `TurnOffWindowsCopilot` | Phase 2 | ✅ Automatisch |
| **M365 Copilot Registry** | 13 Settings (Word, Excel, etc.) | Phase 2 | ✅ Automatisch |
| **Kontextmenü entfernen** | Shell Extension GUID | Phase 3 | ✅ Automatisch |
| **AppLocker Rules** | 5 Deny Rules (XML-Policy) | Phase 4 | ✅ Automatisch |
| **Protocol Handler blockieren** | HKCR Registry Keys | Phase 4b | ✅ Automatisch |
| **Store Auto-Update blockieren** | BlockedPackages Registry | Phase 4c | ✅ Automatisch |
| **DNS-Blockierung** | hosts-Datei (6 Domains) | Phase 5 | ✅ Automatisch |
| **Scheduled Tasks deaktivieren** | `Disable-ScheduledTask` | Phase 6 | ✅ Automatisch |

##### 🔄 Was muss/kann manuell über GPO konfiguriert werden?

Die folgenden Maßnahmen sind **optional** und können über **Group Policy** zentral verwaltet werden:

| Feature | Methode | Vorteil GPO | Empfehlung |
|---------|---------|-------------|------------|
| **Windows Copilot Legacy Policy** | GPO → WindowsCopilot | Zentrale Verwaltung | ⚠️ Depreciert - Script reicht |
| **AppLocker Policy** | GPO → AppLocker | Domain-weite Durchsetzung | ⭐ Empfohlen für Enterprise |
| **M365 Copilot ADMX** | GPO → Office Templates | Benutzer-basierte Policies | ⭐ Empfohlen für Domain |
| **Connected Experiences** | GPO → Office Privacy | Blockiert alle KI-Features | Optional (sehr restriktiv) |
| **Intune/MDM Policies** | Cloud-basierte Verwaltung | Modern Management | ⭐ Für Cloud-Only |

##### 📊 Deployment-Szenarien

##### Szenario 1: Standalone-Rechner / Workgroup
```
✅ Script ausführen: Remove-CopilotComplete.ps1
❌ GPO nicht verfügbar
✅ Ergebnis: Vollständige Blockierung über Registry + AppLocker
```

**Vorteile:**
- Keine Domain erforderlich
- Sofortige Wirkung
- Alle Schutzebenen aktiv

**Nachteile:**
- Keine zentrale Verwaltung
- Manuelle Ausführung auf jedem Rechner

---

##### Szenario 2: Active Directory Domain
```
✅ Script ausführen über: GPO Startup Script / SCCM / Intune
✅ GPO konfigurieren: AppLocker + M365 Copilot Policies
✅ Ergebnis: Zentral verwaltete + lokale Blockierung
```

**Empfohlene Konfiguration:**

**1. GPO Startup Script:**
```
Computer Configuration → Policies → Windows Settings → Scripts → Startup
→ Add: \\domain\netlogon\Remove-CopilotComplete.ps1 -Unattended
```

**2. GPO AppLocker Policy:**
```
Computer Configuration → Windows Settings → Security Settings
→ Application Control Policies → AppLocker → Packaged app Rules
→ Import: CopilotAppLocker.xml
```

**3. GPO M365 Copilot (Optional):**
```
User Configuration → Administrative Templates → Microsoft Office 2016
→ Common → Copilot → Turn Off Copilot: Enabled
```

**Vorteile:**
- Zentrale Verwaltung
- Automatisches Deployment
- GPO überschreibt lokale Änderungen

**Nachteile:**
- Erfordert Domain-Infrastruktur
- ADMX-Templates müssen installiert werden

---

##### Szenario 3: Intune / Modern Management
```
✅ Script deployen: Intune Win32 App / Remediation Script
✅ Intune Policy: WindowsAI CSP + Cloud Policy
✅ Ergebnis: Cloud-basierte zentrale Verwaltung
```

**Empfohlene Konfiguration:**

**1. Intune Remediation Script:**
```
Endpoint Manager → Devices → Scripts and remediations
→ Add: Remove-CopilotComplete.ps1 -Unattended
→ Assign to: All Devices
→ Schedule: Once
```

**2. Intune Configuration Profile:**
```
Settings Catalog → WindowsAI → Turn Off Windows Copilot: Enabled
```

**3. Cloud Policy (M365 Copilot):**
```
M365 Admin Center → Cloud Policy → Disable Copilot: Enabled
→ Assign to: All Users
```

**Vorteile:**
- Cloud-basiert (keine On-Prem-Domain)
- Modern Device Management
- Co-Management möglich

**Nachteile:**
- Erfordert Intune-Lizenzen
- Internet-Abhängig

---

##### 🎯 Empfohlener Ansatz nach Umgebung

##### Klein (< 50 Rechner)
```
✅ Script manuell ausführen
❌ GPO nicht erforderlich (Aufwand > Nutzen)
✅ AppLocker wird vom Script gesetzt
```

##### Mittel (50-500 Rechner)
```
✅ Script über GPO Startup Script
✅ GPO AppLocker Policy (zentral verwaltet)
✅ Optional: M365 Copilot ADMX
```

##### Groß (500+ Rechner / Enterprise)
```
✅ Script über SCCM/Intune Deployment
✅ GPO AppLocker Policy (enforced)
✅ M365 Copilot über ADMX + Cloud Policy
✅ Intune CSP Policies für moderne Geräte
```

---

##### ⚖️ Script vs. GPO - Entscheidungsmatrix

| Kriterium | Script-Only | Script + GPO | Nur GPO |
|-----------|-------------|--------------|---------|
| **Deployment-Speed** | ⭐⭐⭐ Schnell | ⭐⭐ Mittel | ⭐ Langsam |
| **Zentrale Verwaltung** | ❌ Keine | ✅ Ja | ✅ Ja |
| **Vollständigkeit** | ✅ 100% | ✅ 100% | ⚠️ 60-70% |
| **Aufwand Setup** | ⭐ Niedrig | ⭐⭐ Mittel | ⭐⭐⭐ Hoch |
| **Domain erforderlich** | ❌ Nein | ✅ Ja | ✅ Ja |
| **Maintenance** | ⭐⭐ Mittel | ⭐ Niedrig | ⭐⭐ Mittel |

**Legende:**
- **Deployment-Speed:** Wie schnell kann ausgerollt werden
- **Vollständigkeit:** Wie viele Blockierungs-Mechanismen aktiv
- **Aufwand Setup:** Initiale Konfigurationsaufwand

---

##### 📝 Zusammenfassung

##### Das Script macht:
- ✅ **Phase 1-6:** Vollständige lokale Blockierung
- ✅ **Registry:** Alle Windows + M365 Copilot Settings
- ✅ **AppLocker:** 5 Deny Rules (lokal)
- ✅ **DNS:** hosts-Datei Blockierung
- ✅ **Pakete:** Entfernung + Deprovisioning

##### GPO/Intune ergänzt:
- 🔄 **Zentrale Verwaltung:** Policies Domain-weit
- 🔄 **Enforcement:** Policies können nicht lokal geändert werden
- 🔄 **Reporting:** Compliance-Überwachung
- 🔄 **Versionierung:** Policy-Rollback möglich

##### Fazit:
> **Für maximale Sicherheit:** Script + GPO kombinieren
> **Für schnelle Blockierung:** Script alleine reicht aus
> **Für Enterprise:** Script + GPO + Intune (Defense in Depth)

---

##### Windows Copilot Blockierung

##### 1. AppLocker Policy (⭐ Empfohlen)

**Quellen:**
- <a href="https://learn.microsoft.com/en-us/windows/client-management/manage-windows-copilot" target="_blank">Microsoft Learn - Manage Windows Copilot</a>
- <a href="https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/create-a-rule-for-packaged-apps" target="_blank">Microsoft Learn - Create a rule for packaged apps</a> ⭐ **How-To Guide**
- <a href="https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/manage-packaged-apps-with-applocker" target="_blank">Microsoft Learn - Manage packaged apps with AppLocker</a>

> **Microsoft-Statement:**
> *"AppLocker policy should be used instead of the Turn Off Windows Copilot legacy policy setting and its MDM equivalent, TurnOffWindowsCopilot. These policies are subject to near-term deprecation."*

##### AppLocker-Konfiguration

**Publisher-Informationen:**
```
Publisher: CN=MICROSOFT CORPORATION, O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US
Package Name: MICROSOFT.COPILOT
Package Version: * (and above)
```

**GPO-Pfad:**
```
Computer Configuration → Windows Settings → Security Settings → Application Control Policies → AppLocker → Packaged app Rules
```

**Regel-Typ:** Deny
**Bedingung:** Publisher (siehe oben)

##### Manuelle Konfiguration (How-To)

**Schritt-für-Schritt nach Microsoft-Dokumentation:**

1. Öffne **Group Policy Management** (`gpmc.msc`)
2. Navigiere zu: `Computer Configuration → Windows Settings → Security Settings → Application Control Policies → AppLocker`
3. Rechtsklick auf **Packaged app Rules** → **Create New Rule**
4. Wähle: **Permissions** → **Deny**
5. Wähle: **User or group** → **Everyone** (S-1-1-0)
6. Wähle: **Conditions** → **Publisher**
7. Gebe Publisher-Informationen ein:
   - **Publisher Name:** `O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US`
   - **Package Name:** `MICROSOFT.COPILOT`
   - **Package Version:** `*` (all versions)
8. **Finish** und GPO verlinken
9. **AppIDSvc** Service aktivieren (automatisch bei GPO-Anwendung)

---

##### 2. Legacy Group Policy (⚠️ Depreciert)

**Quelle:** <a href="https://learn.microsoft.com/en-us/answers/questions/2200120/disable-microsoft-copilot-via-domain-group-policy" target="_blank">Microsoft Q&A - Disable Copilot via GPO</a>

**GPO-Pfad:**
```
User Configuration → Administrative Templates → Windows Components → Windows Copilot → Turn off Windows Copilot
```

**Registry-Equivalent:**
```
Path:  HKEY_CURRENT_USER\Software\Policies\Microsoft\Windows\WindowsCopilot
Name:  TurnOffWindowsCopilot
Type:  REG_DWORD
Value: 1 (Enable - Copilot disabled)
```

**Status:** ⚠️ **Near-term deprecation** - Nicht für neue Deployments verwenden!

---

##### 3. WindowsAI Policy CSP (Intune/MDM)

**Quelle:** <a href="https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowsai" target="_blank">Microsoft Learn - WindowsAI Policy CSP</a>

**MDM-Policy:**
```
./User/Vendor/MSFT/Policy/Config/WindowsAI/TurnOffWindowsCopilot
```

**Wert:**
- `<enabled/>` - Copilot deaktiviert
- `<disabled/>` - Copilot aktiviert (Standard)

**Intune-Konfiguration:**

1. **Endpoint Manager** → **Devices** → **Configuration profiles**
2. **Create profile** → **Platform: Windows 10 and later** → **Profile type: Settings catalog**
3. Suche: `WindowsAI`
4. Wähle: **Turn Off Windows Copilot**
5. Setze auf: **Enabled**

---

##### Microsoft 365 Copilot Blockierung

##### 1. Connected Experiences deaktivieren

**Quelle:** <a href="https://learn.microsoft.com/en-us/microsoft-365-apps/privacy/manage-privacy-controls" target="_blank">Microsoft Learn - Manage Privacy Controls</a>

**Offizielle Microsoft-Policy:**

> *"If you disable the 'Allow the use of connected experiences in Office' policy setting, Microsoft 365 Copilot features won't be available to your users."*

##### Group Policy-Konfiguration

**GPO-Pfad:**
```
User Configuration → Policies → Administrative Templates → Microsoft Office 2016 → Privacy → Privacy Center
→ "Allow the use of connected experiences in Office that analyze content"
```

**Setze auf:** `Disabled`

**Registry-Equivalent:**
```
Path:  HKEY_CURRENT_USER\Software\Policies\Microsoft\Office\16.0\Common\Privacy
Name:  UserContentDisabled
Type:  REG_DWORD
Value: 2 (Disabled)
```

---

##### 2. Copilot-spezifische Policies

**Quellen:**
- <a href="https://support.microsoft.com/en-us/office/turn-off-copilot-in-microsoft-365-apps-bc7e530b-152d-4123-8e78-edc06f8b85f1" target="_blank">Microsoft Support - Turn off Copilot in M365 Apps</a>
- <a href="https://learn.microsoft.com/en-us/copilot/microsoft-365/microsoft-365-copilot-app-admin-settings" target="_blank">Microsoft Learn - Microsoft 365 Copilot app settings for IT admins</a> ⭐ **How-To Guide**

##### Per-Application Blocking

**Word, Excel, PowerPoint, OneNote:**

```
Path:  HKEY_CURRENT_USER\Software\Policies\Microsoft\Office\16.0\<app>\Options\Copilot
Name:  DisableCopilot
Type:  REG_DWORD
Value: 1 (Disabled)
```

**Apps:** `word`, `excel`, `powerpoint`, `outlook`, `onenote`

##### Zentrale Copilot-Blockierung

**Main Toggle (HKCU):**
```
Path:  HKEY_CURRENT_USER\Software\Policies\Microsoft\Office\16.0\Common\Copilot
Name:  TurnOffCopilot
Type:  REG_DWORD
Value: 1 (Disabled)
```

**Main Toggle (HKLM - Computer-wide):**
```
Path:  HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Copilot
Name:  TurnOffCopilot
Type:  REG_DWORD
Value: 1 (Disabled)
```

##### Additional Controls

**AllowCopilot:**
```
Path:  HKEY_CURRENT_USER\Software\Policies\Microsoft\Office\16.0\Common
Name:  AllowCopilot
Type:  REG_DWORD
Value: 0 (Disabled)
```

**DisableCopilotInOffice:**
```
Path:  HKEY_CURRENT_USER\Software\Policies\Microsoft\Office\16.0\Common\Copilot
Name:  DisableCopilotInOffice
Type:  REG_DWORD
Value: 1 (Disabled)
```

---

##### ADMX/ADML Templates

##### Download-Quellen

**Windows Administrative Templates:**
- **Windows 11:** <a href="https://www.microsoft.com/en-us/download/details.aspx?id=105667" target="_blank">Download ID 105667</a>
- **Windows 10:** <a href="https://www.microsoft.com/en-us/download/details.aspx?id=103124" target="_blank">Download ID 103124</a>

**Microsoft 365 Apps Administrative Templates:**
- **Office ADMX:** <a href="https://www.microsoft.com/en-us/download/details.aspx?id=49030" target="_blank">Download ID 49030</a>
- Enthält: Office LTSC 2024, 2021, 2019, 2016, Microsoft 365 Apps

**Quelle:** <a href="https://www.microsoft.com/en-us/download/details.aspx?id=49030" target="_blank">Microsoft Download Center - Office ADMX</a>

##### Installation

1. **Download** der ADMX/ADML-Dateien
2. **Extrahiere** die Dateien
3. **Kopiere** `.admx` nach: `C:\Windows\PolicyDefinitions\`
4. **Kopiere** `.adml` nach: `C:\Windows\PolicyDefinitions\de-DE\` (für Deutsch)
5. **Für Central Store:** Kopiere nach `\\domain.local\SYSVOL\domain.local\Policies\PolicyDefinitions\`

##### Verfügbare Policies nach Installation

**Windows Copilot:**
- `User Configuration → Administrative Templates → Windows Components → Windows Copilot`

**Microsoft 365 Copilot:**
- `User Configuration → Administrative Templates → Microsoft Office 2016 → Privacy`
- `User Configuration → Administrative Templates → Microsoft Office 2016 → Copilot`

---

##### AppLocker-Konfiguration

##### ⭐ Empfohlene Methode für Windows 11 24H2+

**Quelle:** <a href="https://learn.microsoft.com/en-us/windows/client-management/manage-windows-copilot" target="_blank">Microsoft Learn - Manage Windows Copilot</a>

##### XML-Policy Template

```xml
<AppLockerPolicy Version="1">
    <RuleCollection Type="Exe" EnforcementMode="Enabled">
        <FilePublisherRule Id="{GUID}" Name="Block Microsoft Copilot"
                          Description="Blocks Microsoft Copilot applications"
                          UserOrGroupSid="S-1-1-0" Action="Deny">
            <Conditions>
                <FilePublisherCondition PublisherName="O=MICROSOFT CORPORATION, L=REDMOND, S=WASHINGTON, C=US"
                                       ProductName="Microsoft.Copilot*"
                                       BinaryName="*">
                    <BinaryVersionRange LowSection="*" HighSection="*" />
                </FilePublisherCondition>
            </Conditions>
        </FilePublisherRule>
    </RuleCollection>
</AppLockerPolicy>
```

##### PowerShell-Implementierung

```powershell
# AppLocker Policy erstellen
$xml = @"
<AppLockerPolicy Version="1">
  <!-- XML siehe oben -->
</AppLockerPolicy>
"@

# Policy anwenden
$xml | Out-File -FilePath "C:\Temp\CopilotAppLocker.xml" -Encoding UTF8
Set-AppLockerPolicy -XmlPolicy "C:\Temp\CopilotAppLocker.xml" -Merge

# AppLocker Service starten
Start-Service -Name AppIDSvc
Set-Service -Name AppIDSvc -StartupType Automatic
```

##### GPO-Integration

1. Öffne `gpmc.msc`
2. Navigiere zu: `Computer Configuration → Windows Settings → Security Settings → Application Control Policies → AppLocker`
3. Import Policy: Rechtsklick → **Import Policy**
4. Wähle erstellte XML-Datei
5. GPO verlinken und anwenden

---

##### Intune/MDM-Konfiguration

##### Windows Copilot über Intune blockieren

**Quelle:** <a href="https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowsai" target="_blank">Microsoft Learn - WindowsAI Policy CSP</a>

##### Settings Catalog (Empfohlen)

1. **Endpoint Manager** → **Devices** → **Configuration profiles**
2. **Create profile**
3. **Platform:** Windows 10 and later
4. **Profile type:** Settings catalog
5. **Settings:** Suche `WindowsAI`
6. **Policy:** Turn Off Windows Copilot → **Enabled**

##### Custom OMA-URI

**OMA-URI:**
```
./User/Vendor/MSFT/Policy/Config/WindowsAI/TurnOffWindowsCopilot
```

**Data type:** String
**Value:** `<enabled/>`

##### Microsoft 365 Copilot über Intune

##### Cloud Policy Service

**Quelle:** <a href="https://learn.microsoft.com/en-us/microsoft-365-apps/admin-center/overview-cloud-policy" target="_blank">Microsoft Learn - Overview of Cloud Policy service for Microsoft 365</a> ⭐ **How-To Guide**

**Schritt-für-Schritt nach Microsoft-Dokumentation:**

1. **Microsoft 365 Admin Center** → **Settings** → **Org settings**
2. Klicke auf **Microsoft 365 Apps admin center** (Link im Admin Center)
3. **Cloud Policy** → **Create** → **Create a policy configuration**
4. **Name:** "Disable M365 Copilot"
5. **Scope:** Wähle Benutzergruppe (z.B. "All Users")
6. **Configure policies:**
   - Suche: `Copilot`
   - `Turn off Copilot` → **Enabled**
   - Optional: `Allow the use of connected experiences in Office` → **Disabled**
7. **Review and publish** → **Save**
8. Policy wird innerhalb von 90 Minuten auf alle Geräte angewendet

**Hinweis:** Cloud Policy erfordert keine Domain-Mitgliedschaft, funktioniert für AAD-joined und persönliche Geräte.

##### Configuration Profile (Registry)

**Profil-Typ:** Custom
**OMA-URI Settings:**

```
Name: Disable M365 Copilot
OMA-URI: ./User/Vendor/MSFT/Policy/Config/ADMX_office16/L_UserContentDisabled
Data type: String
Value: <enabled/>
```

---

##### Verifikation

##### Windows Copilot

**PowerShell-Check:**
```powershell
# Registry prüfen
Get-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue

# Copilot-Paket prüfen
Get-AppxPackage -Name "Microsoft.Copilot" -AllUsers

# AppLocker Policy prüfen
Get-AppLockerPolicy -Effective | Select-Object -ExpandProperty RuleCollections
```

**Erwartetes Ergebnis:**
- Registry: `TurnOffWindowsCopilot = 1`
- Paket: Nicht gefunden ODER
- AppLocker: Deny-Rule für Microsoft.Copilot vorhanden

##### Microsoft 365 Copilot

**PowerShell-Check:**
```powershell
# Office Copilot Registry prüfen
Get-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Office\16.0\Common\Copilot" -Name "TurnOffCopilot" -ErrorAction SilentlyContinue

# Per-App Copilot prüfen
$Apps = @('word', 'excel', 'powerpoint', 'outlook', 'onenote')
foreach ($App in $Apps) {
    $Path = "HKCU:\Software\Policies\Microsoft\Office\16.0\$App\Options\Copilot"
    Get-ItemProperty -Path $Path -Name "DisableCopilot" -ErrorAction SilentlyContinue
}

# Connected Experiences prüfen
Get-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Office\16.0\Common\Privacy" -Name "UserContentDisabled" -ErrorAction SilentlyContinue
```

**Erwartetes Ergebnis:**
- `TurnOffCopilot = 1`
- `DisableCopilot = 1` (für alle Apps)
- `UserContentDisabled = 2`

##### GPO-Anwendung prüfen

**Group Policy Results:**
```cmd
gpresult /h C:\GPReport.html
gpresult /r /scope:user
```

**PowerShell:**
```powershell
Get-GPResultantSetOfPolicy -ReportType Html -Path C:\GPReport.html
```

---

##### Quellen

##### Offizielle Microsoft-Dokumentation

##### Windows Copilot

1. **Manage Windows Copilot** (Policy Recommendations)
   <a href="https://learn.microsoft.com/en-us/windows/client-management/manage-windows-copilot" target="_blank">https://learn.microsoft.com/en-us/windows/client-management/manage-windows-copilot</a>

2. **WindowsAI Policy CSP** (Intune/MDM)
   <a href="https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowsai" target="_blank">https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowsai</a>

##### AppLocker (⭐ How-To Guides)

3. **Create a rule for packaged apps** (AppLocker How-To)
   <a href="https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/create-a-rule-for-packaged-apps" target="_blank">https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/create-a-rule-for-packaged-apps</a>

4. **Manage packaged apps with AppLocker** (AppLocker Management)
   <a href="https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/manage-packaged-apps-with-applocker" target="_blank">https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/applocker/manage-packaged-apps-with-applocker</a>

##### Microsoft 365 Copilot

5. **Turn off Copilot in Microsoft 365 Apps** (Registry Keys)
   <a href="https://support.microsoft.com/en-us/office/turn-off-copilot-in-microsoft-365-apps-bc7e530b-152d-4123-8e78-edc06f8b85f1" target="_blank">https://support.microsoft.com/en-us/office/turn-off-copilot-in-microsoft-365-apps-bc7e530b-152d-4123-8e78-edc06f8b85f1</a>

6. **Microsoft 365 Copilot app settings for IT admins** (⭐ How-To Guide)
   <a href="https://learn.microsoft.com/en-us/copilot/microsoft-365/microsoft-365-copilot-app-admin-settings" target="_blank">https://learn.microsoft.com/en-us/copilot/microsoft-365/microsoft-365-copilot-app-admin-settings</a>

7. **Manage Privacy Controls for Microsoft 365 Apps** (Connected Experiences)
   <a href="https://learn.microsoft.com/en-us/microsoft-365-apps/privacy/manage-privacy-controls" target="_blank">https://learn.microsoft.com/en-us/microsoft-365-apps/privacy/manage-privacy-controls</a>

8. **Overview of Cloud Policy service for Microsoft 365** (⭐ How-To Guide)
   <a href="https://learn.microsoft.com/en-us/microsoft-365-apps/admin-center/overview-cloud-policy" target="_blank">https://learn.microsoft.com/en-us/microsoft-365-apps/admin-center/overview-cloud-policy</a>

##### ADMX/ADML Templates

9. **Administrative Template Files (ADMX/ADML) for Microsoft Office**
   <a href="https://www.microsoft.com/en-us/download/details.aspx?id=49030" target="_blank">https://www.microsoft.com/en-us/download/details.aspx?id=49030</a>

10. **Windows 11 Administrative Templates**
    <a href="https://www.microsoft.com/en-us/download/details.aspx?id=105667" target="_blank">https://www.microsoft.com/en-us/download/details.aspx?id=105667</a>

##### Microsoft Community & Q&A

11. **Disable Microsoft Copilot via Domain Group Policy** (Legacy GPO)
    <a href="https://learn.microsoft.com/en-us/answers/questions/2200120/disable-microsoft-copilot-via-domain-group-policy" target="_blank">https://learn.microsoft.com/en-us/answers/questions/2200120/disable-microsoft-copilot-via-domain-group-policy</a>

---

##### Zusammenfassung

##### ✅ Empfohlene Deployment-Strategie

1. **Windows Copilot:**
   - ⭐ **Primär:** AppLocker Policy (zukunftssicher)
   - 🔄 **Fallback:** TurnOffWindowsCopilot Registry (depreciert, aber noch funktional)

2. **Microsoft 365 Copilot:**
   - ⭐ **Primär:** ADMX Templates + GPO (`TurnOffCopilot` Policy)
   - 🔄 **Fallback:** Registry-Keys (`TurnOffCopilot`, `DisableCopilot`)
   - 🛡️ **Zusätzlich:** Connected Experiences deaktivieren

3. **Verifikation:**
   - PowerShell-Scripts zur automatischen Prüfung
   - GPResult Reports
   - User-Tests

##### ⚠️ Wichtige Hinweise

- **Deprecation:** Legacy-Policies werden von Microsoft eingestellt
- **Windows 11 24H2+:** AppLocker ist EINZIGE zuverlässige Methode
- **Testing:** Immer in Test-Umgebung validieren vor Prod-Rollout
- **Updates:** Microsoft ändert Copilot-Integration kontinuierlich

---

**Dokument-Version:** 1.0
**Letztes Update:** 19. November 2025
**Autor:** IT-Administration
**Status:** ✅ Freigegeben für Deployment
