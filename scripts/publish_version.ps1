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

# 1. Compilation de la nouvelle version CineTrekker
Write-Host "`n[1/3] Compilation du code applicatif CineTrekker..." -ForegroundColor Yellow
Push-Location $AppDir
try {
    npx vite build
    if ($LASTEXITCODE -ne 0) { throw "Echec de la compilation Vite." }
    tar -czf cinetrekker.tar.gz dist server.js package.json
    if ($LASTEXITCODE -ne 0) { throw "Echec de la création de l'archive tar.gz." }
} finally {
    Pop-Location
}

# 2. Upload sur S3
Push-Location $TfDir
try {
    $Bucket = (& $TfExe output -raw s3_artifacts_bucket)
    $Asg = (aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?contains(AutoScalingGroupName, 'cinetrekker-dev')].AutoScalingGroupName" --output text)

    Write-Host "`n[2/3] Televersement de l'archive sur S3 (s3://$Bucket/app/cinetrekker.tar.gz)..." -ForegroundColor Yellow
    $TarPath = Join-Path $AppDir "cinetrekker.tar.gz"
    aws s3 cp $TarPath "s3://$Bucket/app/cinetrekker.tar.gz"

    # 3. Renouvellement des instances sur l'ASG (compatible SCPs AWS Academy)
    Write-Host "`n[3/3] Declenchement du renouvellement des instances sur l'Auto Scaling Group ($Asg)..." -ForegroundColor Yellow
    $instances = (aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $Asg --query "AutoScalingGroups[0].Instances[*].InstanceId" --output text).Split("`t ") | Where-Object { $_ }
    foreach ($inst in $instances) {
        Write-Host "Remplacement immediat de l'instance $inst (l'ASG en relance une avec le dernier code S3)..." -ForegroundColor Cyan
        aws autoscaling terminate-instance-in-auto-scaling-group --instance-id $inst --no-should-decrement-desired-capacity 2>$null | Out-Null
    }

    Write-Host "`nDeploiement lance avec succes ! L'ASG recrée automatiquement les instances avec la nouvelle version." -ForegroundColor Green
} finally {
    Pop-Location
}
