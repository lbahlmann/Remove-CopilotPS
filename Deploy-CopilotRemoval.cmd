@echo off
REM ============================================
REM Microsoft Copilot Removal - Full Unattended
REM Version: 2.2.1
REM Fuer GPO/Intune/SCCM Deployment
REM ============================================
REM
REM Dieses Script:
REM 1. Entfernt Microsoft Copilot vollstaendig
REM 2. Installiert Script in sicheren Pfad (C:\Program Files\badata\)
REM 3. Erstellt Scheduled Task fuer automatische Ausfuehrung
REM 4. Startet System neu (nach 60 Sekunden Warnung)
REM
REM ============================================

echo.
echo ================================================
echo Microsoft Copilot Removal Toolkit v2.2.1
echo FULL UNATTENDED DEPLOYMENT
echo ================================================
echo.

REM Pruefe Admin-Rechte
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [FEHLER] Administratorrechte erforderlich!
    echo.
    echo Bitte als Administrator ausfuehren:
    echo   Rechtsklick -^> Als Administrator ausfuehren
    echo.
    pause
    exit /b 1
)

echo [OK] Administratorrechte vorhanden
echo.
echo Starte Copilot-Entfernung...
echo.

REM Copilot entfernen + Task einrichten + Reboot (Unattended fuer GPO)
powershell.exe -ExecutionPolicy Bypass -WindowStyle Normal -File "%~dp0Remove-CopilotComplete.ps1" -Unattended -CreateScheduledTask -WithReboot

REM Exit-Code des PowerShell-Scripts uebernehmen
set PS_EXIT=%errorLevel%

if %PS_EXIT% equ 0 (
    echo.
    echo ================================================
    echo [OK] Deployment erfolgreich abgeschlossen!
    echo ================================================
    echo.
    echo Das System wird in 60 Sekunden neu gestartet.
    echo.
) else (
    echo.
    echo ================================================
    echo [FEHLER] Deployment mit Fehlern beendet (Exit: %PS_EXIT%)
    echo ================================================
    echo.
    echo Bitte Log-Dateien pruefen.
    echo.
)

exit /b %PS_EXIT%
