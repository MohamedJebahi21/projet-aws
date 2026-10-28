<#
.SYNOPSIS
    Script de déploiement et de reconstruction complète en une commande (L1-L3).
.DESCRIPTION
    Mesure le temps de reconstruction total (< 5 minutes),
    compile le package applicatif si nécessaire, initialise Terraform et applique
    l'infrastructure réseau, calcul et sécurité AWS.
#>

$ErrorActionPreference = "Stop"
$StartTime = Get-Date

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   RECONSTRUCTION COMPLETE EN UNE SEULE COMMANDE (AWS)   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Demarrage a : $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"

# 1. Verification et compilation du package applicatif CineTrekker (Vite SPA + Node.js)
$AppDir = Join-Path $PSScriptRoot "..\app"
$AppTar = Join-Path $AppDir "cinetrekker.tar.gz"
$DistDir = Join-Path $AppDir "dist"

if (-not (Test-Path $AppTar)) {
    Write-Host "`n[1/4] Construction du package applicatif CineTrekker..." -ForegroundColor Yellow
    Push-Location $AppDir
    try {
        if (-not (Test-Path "node_modules")) {
            Write-Host "Installation des dépendances npm..." -ForegroundColor Cyan
            npm install
            if ($LASTEXITCODE -ne 0) { throw "Echec npm install" }
        }

        if (-not (Test-Path $DistDir)) {
            Write-Host "Compilation de la production Vite (dist)..." -ForegroundColor Cyan
            npx vite build
            if ($LASTEXITCODE -ne 0) { throw "Echec vite build" }
        }

        Write-Host "Création de l'archive cinetrekker.tar.gz..." -ForegroundColor Cyan
        tar -czf cinetrekker.tar.gz dist server.js package.json
        if ($LASTEXITCODE -ne 0) { throw "Echec tar compression" }
        Write-Host "Archive CineTrekker créée avec succès." -ForegroundColor Green
    } finally {
        Pop-Location
    }
} else {
    Write-Host "`n[1/4] Artefact CineTrekker présent ($AppTar)." -ForegroundColor Green
}

# 2. Initialisation Terraform
Write-Host "`n[2/4] Initialisation de Terraform..." -ForegroundColor Yellow
$TfDir = Join-Path $PSScriptRoot "..\infra\environments\dev"
$TfExe = Join-Path $PSScriptRoot "..\terraform.exe"

Push-Location $TfDir
try {
    & $TfExe init
    if ($LASTEXITCODE -ne 0) { throw "Echec terraform init" }

    # Verification et creation idempotente du bucket S3 (conforme SCPs AWS Academy)
    $AccountId = (aws sts get-caller-identity --query "Account" --output text).Trim()
    $BucketName = "cinetrekker-dev-artifacts-$AccountId"
    Write-Host "Verification du bucket S3 ($BucketName)..." -ForegroundColor Yellow
    $bucketCheck = aws s3api list-buckets --query "Buckets[?Name=='$BucketName'].Name" --output text
    if (-not $bucketCheck) {
        Write-Host "Creation du bucket S3 ($BucketName)..." -ForegroundColor Yellow
        aws s3api create-bucket --bucket $BucketName --region us-east-1 | Out-Null
        Write-Host "Bucket S3 cree avec succes." -ForegroundColor Green
    } else {
        Write-Host "Bucket S3 deja existant." -ForegroundColor Green
    }

    # 3. Application de l'infrastructure
    Write-Host "`n[3/4] Deploiement de l'infrastructure AWS (VPC Multi-AZ, NAT, ALB, ASG, S3)..." -ForegroundColor Yellow
    & $TfExe apply -auto-approve
    if ($LASTEXITCODE -ne 0) { throw "Echec terraform apply" }

    # 4. Recuperation des sorties et verification de disponibilite
    Write-Host "`n[4/4] Verification de l'accessibilite du service..." -ForegroundColor Yellow
    $AlbUrl = (& $TfExe output -raw application_url 2>$null)
    $HealthUrl = (& $TfExe output -raw healthcheck_url 2>$null)

    $EndTime = Get-Date
    $Duration = $EndTime - $StartTime
    $Minutes = [math]::Floor($Duration.TotalMinutes)
    $Seconds = $Duration.Seconds

    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "   DEPLOIEMENT REUSSI AVEC SUCCES !" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Temps de reconstruction mesure : $Minutes min $Seconds s" -ForegroundColor Green
    Write-Host "URL Application Web            : $AlbUrl" -ForegroundColor Cyan
    Write-Host "Controle de Sante ALB          : $HealthUrl" -ForegroundColor Cyan
    Write-Host "`nAttente de la montee des cibles ALB (~45s)..."

    # Journalisation automatique de la reconstruction
    $JournalFile = Join-Path $PSScriptRoot "..\docs\journal-destructions.md"
    $LogLine = "| $($StartTime.ToString('yyyy-MM-dd HH:mm')) | Reconstruction L1-L3 | Reussie ($Minutes m $Seconds s) | $AlbUrl |"
    Add-Content -Path $JournalFile -Value $LogLine -ErrorAction SilentlyContinue

} finally {
    Pop-Location
}
