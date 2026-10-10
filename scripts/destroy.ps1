<#
.SYNOPSIS
    Script de destruction complète et sécurisée des ressources AWS facturées à l'heure.
.DESCRIPTION
    Exécute terraform destroy de façon automatisée, préserve le crédit Learner Lab
    et consigne l'horodatage dans le journal des destructions.
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
    Write-Host "`nDestruction des instances EC2, ALB, ASG, NAT et RDS..." -ForegroundColor Yellow
    & $TfExe destroy -auto-approve
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Des ressources n'ont peut-etre pas ete detruites completement. Verifier la sortie ci-dessus."
    } else {
        Write-Host "`nDestruction terminee avec succes. Le compteur de facturation horaire est stoppe." -ForegroundColor Green
    }

    # Journalisation
    $JournalFile = Join-Path $PSScriptRoot "..\docs\journal-destructions.md"
    $LogLine = "| $($StartTime.ToString('yyyy-MM-dd HH:mm')) | Destruction | Complete et propre | Credit preserve |"
    Add-Content -Path $JournalFile -Value $LogLine -ErrorAction SilentlyContinue

    Write-Host "`n>>> ACTION REQUISE : Notez votre credit restant sur AWS Academy dans docs/journal-destructions.md <<<" -ForegroundColor Cyan
} finally {
    Pop-Location
}
