param(
    [parameter(Mandatory = $true)] [String] $templateProjetPath
    ,[parameter(Mandatory = $true)] [String] $environement
)
$templateProject = Get-Content -Path $templateProjetPath -Encoding UTF8 | ConvertFrom-Json
#Connect-AzAccount -Tenant '01cad88a-b9c8-4c54-ad8d-c6920c250e4b' -SubscriptionId '2af7e41e-dad9-4712-90a3-ef6aa1a97bf5'
#Generate project name
$rgName = "dp-"+$environement+"-"+$templateProject."Code Projet"
$devopsName = "dp-"+$templateProject."Code Projet"

Import-module ".\UsineDeploiement\Modules\project-init.ps1" -Force

Write-Host "**Deploying RG $projectName **"
Set-RG $rgName $templateProject $environement
Write-Host "**Deploying Devops Project $projectName **"
Set-Devops $devopsName $environement
Write-Host "**Creating Devops Service Connection $projectName **"
Set-ServiceConnections $devopsName $rgName