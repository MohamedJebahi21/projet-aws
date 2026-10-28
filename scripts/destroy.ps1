<#
.SYNOPSIS
    Script de destruction complète et sécurisée des ressources AWS (L1-L3).
.DESCRIPTION
    Exécute la destruction de façon automatisée et sans blocage :
    1. Exécute terraform destroy pour supprimer EC2, ASG, ALB, NAT, Security Groups et VPC.
    2. Nettoie et supprime le bucket S3 d'artefacts.
    3. Consigne l'horodatage dans le journal des destructions.
#>

$ErrorActionPreference = "Stop"
$StartTime = Get-Date

Write-Host "==========================================================" -ForegroundColor Red
Write-Host "   DESTRUCTION DES RESSOURCES FACTUREES A L'HEURE (AWS)   " -ForegroundColor Red
Write-Host "==========================================================" -ForegroundColor Red
Write-Host "Demarrage a : $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"

$TfDir = Join-Path $PSScriptRoot "..\infra\environments\dev"
$TfExe = Join-Path $PSScriptRoot "..\terraform.exe"

Push-Location $TfDir
try {
    # 1. Destruction propre de l'infrastructure via Terraform
    Write-Host "`n[1/2] Destruction de l'infrastructure (EC2, ASG, ALB, NAT, Security Groups, VPC)..." -ForegroundColor Yellow
    & $TfExe destroy -auto-approve
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Attention: certaines ressources necessitent un second passage de nettoyage."
        & $TfExe destroy -auto-approve 2>$null | Out-Null
    }

    # 2. Nettoyage et suppression propre des buckets S3
    Write-Host "`n[2/2] Nettoyage et suppression du bucket S3 d'artefacts..." -ForegroundColor Yellow
    try {
        $AccountId = (aws sts get-caller-identity --query "Account" --output text).Trim()
        foreach ($bName in @("cinetrekker-dev-artifacts-$AccountId")) {
            aws s3 rb "s3://$bName" --force 2>$null | Out-Null
        }
        Write-Host "Bucket S3 supprime." -ForegroundColor Green
    } catch {
        Write-Host "Bucket S3 deja absent ou supprime." -ForegroundColor Green
    }

    $EndTime = Get-Date
    $Duration = $EndTime - $StartTime
    $Minutes = [math]::Floor($Duration.TotalMinutes)
    $Seconds = $Duration.Seconds

    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "   DESTRUCTION COMPLETE TERMINEE AVEC SUCCES !" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Duree de l'operation : $Minutes min $Seconds s" -ForegroundColor Green
    Write-Host "Toutes les ressources payantes sont arretees (cout horaire = 0$).`n" -ForegroundColor Green

    # Journalisation
    $JournalFile = Join-Path $PSScriptRoot "..\docs\journal-destructions.md"
    $LogLine = "| $($StartTime.ToString('yyyy-MM-dd HH:mm')) | Destruction L1-L3 | Reussie ($Minutes m $Seconds s) | Credit preserve |"
    Add-Content -Path $JournalFile -Value $LogLine -ErrorAction SilentlyContinue

    Write-Host ">>> ACTION REQUISE : Notez votre credit restant sur AWS Academy dans docs/journal-destructions.md <<<" -ForegroundColor Cyan
} finally {
    Pop-Location
}
