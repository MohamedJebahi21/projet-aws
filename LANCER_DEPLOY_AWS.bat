@echo off
title Deploiement 1-Clic Infrastructure AWS (ING-4-CIM)
color 0B

echo ======================================================================
echo    LANCEMENT AUTOMATIQUE DU DEPLOIEMENT AWS 3-TIERS (1-CLIC)
echo ======================================================================
echo.
echo Verification des identifiants AWS temporaires...

python -c "import boto3; s = boto3.client('sts'); print('[OK] Connecte au compte:', s.get_caller_identity()['Account'])" 2>nul
if errorlevel 1 (
    echo.
    echo [ERREUR] Vos identifiants AWS sont invalides ou expires !
    echo.
    echo Solution :
    echo 1. Connectez-vous sur AWS Academy Learner Lab et cliquez sur 'Start Lab'.
    echo 2. Cliquez sur 'AWS Details' puis 'Show AWS CLI credentials'.
    echo 3. Copiez vos identifiants dans C:\Users\user\.aws\credentials
    echo.
    pause
    exit /b 1
)

echo.
echo Demarrage du script de reconstruction complete...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\deploy.ps1"

echo.
echo ======================================================================
echo Fin de l'operation. Appuyez sur une touche pour fermer cette fenetre.
echo ======================================================================
pause
