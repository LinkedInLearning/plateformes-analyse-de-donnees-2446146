#Function used to deploy or update a resource group
function Set-RG($rgName,$templateProject,$environement) {
    #Tags
    $codeProjet = $templateProject."Code Projet"
    $confidentialite = $templateProject."Confidentialite"
    $description = $templateProject."Description"
    $Owner = $templateProject."Owner"
    $Pole = $templateProject."Pole"
    $CostCenter = $templateProject.Facturation."Cost Center"

    $rqExist = az group exists --name $rgName
    if($rqExist -eq  'true')
    {
        #Update RG
        Write-Host "** Updating RG $rgName **"
        az group update --name $rgName `
        --tags CodeProjet=$codeProjet Confidentialite=$confidentialite Description=$description Owner=$Owner Pole=$Pole CostCenter=$CostCenter 
    }
    else {
        #RG Creation
        Write-Host "** Creating RG $rgName **"
        az group create --location $templateProject."Region" `
        --name $rgName `
        --tags CodeProjet=$codeProjet Confidentialite=$confidentialite Description=$description Owner=$Owner Pole=$Pole CostCenter=$CostCenter 
    }

}

#Function used to deploy or update an azure devops project
function Set-Devops($devopsName,$environement){
  
    if($environement -eq "dev")
    {
        try {
            az devops project create --name $devopsName
        }
        catch {
            Write-Host "** Project $devopsName already exist **"
        }
        

       
    }
    
}

function Set-ServiceConnections($devopsName,$rgName)
{ 

    $secret = az keyvault secret show --name "DevOpsPAT" --vault-name "dp-principal-kv" --query "value" -o tsv

    Import-module ".\UsineDeploiement\Modules\AzDoServiceConnection.ps1" -Force

    $Parameters = @{
        AzServicePrincipalName = "SPN_DEVOPS_$devopsName"
        AzSubscriptionName     = "Microsoft Azure Sponsorship - 12k"
        AzResourceGroupScope   = $rgName
        AzRole                 = "Contributor"
        AzDoOrganizationName   = "monentreprise"
        AzDoProjectName        = $devopsName
        AzDoUserName           = ""
        AzDoToken              = $secret
    }
    
    try {
        New-AzDoSC @Parameters
    }
    catch {
        if($Error[0] -like "*Service connection with name * already exists*")
        {
            Write-Host "** Service connection already configured **"
        }
        else {
            Write-Host "** $Error[0] **"
        }
    }
    

    
}