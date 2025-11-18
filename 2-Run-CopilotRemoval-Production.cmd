@echo off
REM Microsoft Copilot Removal - Produktiv-Ausfuehrung
REM Umgeht Execution Policy und startet mit Admin-Rechten

echo.
echo ================================================
echo Microsoft Copilot Removal Toolkit v2.1
echo PRODUKTIV-MODUS
echo ================================================
echo.
echo WARNUNG: Dieses Script nimmt Aenderungen am System vor!
echo.

REM Ueberpruefen ob Admin-Rechte vorhanden
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Administratorrechte vorhanden
    goto :confirm
) else (
    echo [INFO] Fordere Administrator-Rechte an...
    goto :elevate
)

:elevate
REM Als Administrator neu starten
powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"%~f0\"' -Verb RunAs"
exit /b

:confirm
echo.
set /p CONFIRM="Fortfahren? (J/N): "
if /i "%CONFIRM%" NEQ "J" (
    echo Abgebrochen.
    timeout /t 3 >nul
    exit /b
)

:run
echo.
echo Starte Remove-CopilotComplete.ps1...
echo.

REM Produktiv-Ausfuehrung
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Remove-CopilotComplete.ps1"

echo.
echo ================================================
echo Ausfuehrung abgeschlossen!
echo ================================================
echo.
echo Druecken Sie eine beliebige Taste um zu beenden...
pause >nul
