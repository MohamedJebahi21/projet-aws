@echo off
title Destruction Propre CineTrekker et Arret Facturation AWS (1-Clic)
color 0C

echo ======================================================================
echo    DESTRUCTION COMPLETE CINETREKKER — ARRET FACTURATION (1-CLIC)
echo ======================================================================
echo.
echo Cette operation va detruire :
echo - Les instances EC2 et l'Auto Scaling Group
echo - L'Application Load Balancer (ALB)
echo - L'instance RDS PostgreSQL
echo - L'instance NAT
echo.
echo Cela arrete immediatement la facturation et preserve vos 50$ !
echo.

echo Verification des identifiants AWS...
aws sts get-caller-identity >nul 2>&1
if errorlevel 1 (
    echo [ERREUR] IDENTIFIANTS AWS ACADEMY INVALIDES OU LAB ARRETE.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\destroy.ps1"

echo.
echo ======================================================================
echo Destruction terminee. Votre budget est securise.
echo Appuyez sur une touche pour fermer cette fenetre.
echo ======================================================================
pause
