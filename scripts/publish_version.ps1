<#
.SYNOPSIS
    Procédure scriptée de publication d'une nouvelle version sans interruption (Rolling Update).
.DESCRIPTION
    1. Recompile le code source avec Maven.
    2. Téléverse le nouveau JAR sur Amazon S3.
    3. Déclenche le renouvellement progressif des instances de l'Auto Scaling Group (Instance Refresh).
    4. Garantit la disponibilité continue du service grâce au seuil MinHealthyPercentage = 50%.
#>

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   PUBLICATION SANS INTERRUPTION (ROLLING REFRESH ASG)   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$TfDir = Join-Path $PSScriptRoot "..\infra\environments\dev"
$TfExe = Join-Path $PSScriptRoot "..\terraform.exe"
$AppDir = Join-Path $PSScriptRoot "..\app"

# 1. Compilation de la nouvelle version
Write-Host "`n[1/3] Compilation du code applicatif..." -ForegroundColor Yellow
$MavenCmd = "C:\ProgramData\chocolatey\lib\maven\apache-maven-3.9.15\bin\mvn.cmd"
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

Push-Location $AppDir
try {
    & $MavenCmd clean package -DskipTests
    if ($LASTEXITCODE -ne 0) { throw "Echec de la compilation Maven." }
} finally {
    Pop-Location
}

# 2. Upload sur S3
Push-Location $TfDir
try {
    $Bucket = (& $TfExe output -raw s3_artifacts_bucket)
    $AsgName = (& $TfExe output -json | ConvertFrom-Json | Select-Object -ExpandProperty alb_dns_name -ErrorAction SilentlyContinue)
    # Recuperer le nom de l'ASG via Terraform ou awscli
    $Asg = (python -m awscli autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?contains(AutoScalingGroupName, 'biblio-dev')].AutoScalingGroupName" --output text)

    Write-Host "`n[2/3] Televersement de l'artefact sur S3 (s3://$Bucket/app/bibliotheque-app.jar)..." -ForegroundColor Yellow
    $JarPath = Join-Path $AppDir "target\bibliotheque-app.jar"
    python -m awscli s3 cp $JarPath "s3://$Bucket/app/bibliotheque-app.jar"

    # 3. Declenchement du Rolling Refresh sur l'ASG
    Write-Host "`n[3/3] Declenchement du Rolling Update sur l'Auto Scaling Group ($Asg)..." -ForegroundColor Yellow
    python -m awscli autoscaling start-instance-refresh `
        --auto-scaling-group-name $Asg `
        --preferences '{"MinHealthyPercentage": 50, "InstanceWarmup": 120}'

    Write-Host "`nDeploiement lance avec succes ! Les instances sont renouvelees une par une sans interruption." -ForegroundColor Green
} finally {
    Pop-Location
}
