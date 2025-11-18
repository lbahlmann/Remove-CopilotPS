@echo off
REM Microsoft Copilot Removal - Starter Script
REM Umgeht Execution Policy und startet mit Admin-Rechten

echo.
echo ================================================
echo Microsoft Copilot Removal Toolkit v2.1
echo ================================================
echo.
echo Starte Script mit Administrator-Rechten...
echo.

REM Ueberpruefen ob Admin-Rechte vorhanden
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Administratorrechte vorhanden
    goto :run
) else (
    echo [INFO] Fordere Administrator-Rechte an...
    goto :elevate
)

:elevate
REM Als Administrator neu starten
powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"%~f0\"' -Verb RunAs"
exit /b

:run
REM Script mit Execution Policy Bypass ausfuehren
echo.
echo Starte Remove-CopilotComplete.ps1...
echo.

REM Testlauf (LogOnly)
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Remove-CopilotComplete.ps1" -LogOnly

echo.
echo ================================================
echo Testlauf abgeschlossen!
echo ================================================
echo.
echo Druecken Sie eine beliebige Taste um zu beenden...
pause >nul
