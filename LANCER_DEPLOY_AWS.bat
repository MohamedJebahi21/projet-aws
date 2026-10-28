@echo off
title Deploiement 1-Clic Infrastructure CineTrekker AWS 3-Tiers
color 0B

echo ======================================================================
echo    LANCEMENT DU DEPLOIEMENT AWS 3-TIERS — CINETREKKER (1-CLIC)
echo ======================================================================
echo.
echo Verification des identifiants AWS temporaires...

aws sts get-caller-identity >nul 2>&1
if errorlevel 1 (
    echo.
    echo ======================================================================
    echo [ERREUR] IDENTIFIANTS AWS ACADEMY INVALIDES OU LAB ARRETE
    echo ======================================================================
    echo 1. Ouvrez AWS Academy Learner Lab et cliquez sur 'Start Lab'.
    echo 2. Attendez que le voyant 'AWS' devienne VERT.
    echo 3. Cliquez sur 'AWS Details' puis 'Show' a cote de AWS CLI credentials.
    echo 4. Mettez a jour le fichier %%USERPROFILE%%\.aws\credentials
    echo ======================================================================
    echo.
    pause
    exit /b 1
)

echo [OK] Connecte au compte AWS Academy.

echo.
echo Demarrage du script de reconstruction complete...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\deploy.ps1"

echo.
echo ======================================================================
echo Fin de l'operation. Appuyez sur une touche pour fermer cette fenetre.
echo ======================================================================
pause
