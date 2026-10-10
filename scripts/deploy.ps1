<#
.SYNOPSIS
    Script de déploiement et de reconstruction complète en une commande.
.DESCRIPTION
    Mesure le temps de reconstruction total (objectif chiffré : < 20 minutes),
    compile le package JAR si nécessaire, initialise Terraform et applique
    l'infrastructure 3-tiers AWS.
#>

$ErrorActionPreference = "Stop"
$StartTime = Get-Date

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   RECONSTRUCTION COMPLETE EN UNE SEULE COMMANDE (AWS)   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Demarrage a : $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"

# 1. Verification et compilation du package applicatif JAR
$AppJar = Join-Path $PSScriptRoot "..\app\target\bibliotheque-app.jar"
if (-not (Test-Path $AppJar)) {
    Write-Host "`n[1/4] Compilation du package applicatif avec Maven..." -ForegroundColor Yellow
    $MavenCmd = "C:\ProgramData\chocolatey\lib\maven\apache-maven-3.9.15\bin\mvn.cmd"
    $env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot"
    $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

    & $MavenCmd -f (Join-Path $PSScriptRoot "..\app\pom.xml") clean package -DskipTests
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Echec de la compilation Maven."
    }
} else {
    Write-Host "`n[1/4] Artefact JAR present ($AppJar)." -ForegroundColor Green
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
    $BucketName = "biblio-dev-artifacts-$AccountId"
    $BucketCheck = aws s3api head-bucket --bucket $BucketName 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`nPreparation du bucket S3 conforme AWS Academy ($BucketName)..." -ForegroundColor Yellow
        aws s3api create-bucket --bucket $BucketName --region us-east-1 | Out-Null
    }

    # 3. Application de l'infrastructure
    Write-Host "`n[3/4] Deploiement de l'infrastructure AWS (VPC, ALB, ASG, RDS, S3, CloudWatch)..." -ForegroundColor Yellow
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
    Write-Host "`nAttente de la montee des cibles ALB (~60s)..."

    # Journalisation automatique de la reconstruction
    $JournalFile = Join-Path $PSScriptRoot "..\docs\journal-destructions.md"
    $LogLine = "| $($StartTime.ToString('yyyy-MM-dd HH:mm')) | Reconstruction | Reussie ($Minutes m $Seconds s) | $AlbUrl |"
    Add-Content -Path $JournalFile -Value $LogLine -ErrorAction SilentlyContinue

} finally {
    Pop-Location
}
