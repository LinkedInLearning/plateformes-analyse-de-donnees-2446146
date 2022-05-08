Function New-AzDoSC {
    <#
    .SYNOPSIS
    This function creates an Azure DevOps service connection for AzureRM.
    .DESCRIPTION
    A service principal with set permissions is created in Azure.
    This principal is used to create an AzureRM service connection in Azure DevOps
    .PARAMETER AzServicePrincipalName
    The name the Service Principal in Azure. Has to be unique
    .PARAMETER AzSubscriptionName
    The subscription that the service connection will connect to.
    If no resourcegroupscope is added, permissions will be set to this subscription
    .PARAMETER AzResourceGroupScope
    A resourcegroup that the Connection needs permissions to.
    If left empty, permissions will be set to the subscription.
    .PARAMETER AzRole
    The AzRoleDefinition that the Service principal needs
    .PARAMETER AzDoOrganizationName
    The organization name in Azure DevOps
    .PARAMETER AzDoProjectName
    The project name in Azure DevOps
    .PARAMETER AzDoConnectionName
    A name for the Azure DevOps Connection.
    If left empty, defaults to the name of the subscription without spaces
    .PARAMETER AzDoUserName
    The username to use to connect to Azure DevOps
    .PARAMETER AzDoToken
    The PAT token to use to connect to Azure DevOps
    .EXAMPLE
    $Parameters = @{
    AzServicePrincipalName = example
    AzSubscriptionName = "subscription01"
    AzResourceGroupScope = "RG01"
    AzRole = "owner"
    AzDoOrganizationName = AzDoCompany
    AzDoProjectName = AzureDeployment
    AzDoUserName = user@domain.com
    AzDoToken = "afweafawe3228faefa0w32f0A"
    }
    New-AzDoServiceConnection @Parameters
    ===
    Will create a serviceprincipal called example with owner permissions to the resourcegroup RG01.
    Will create a connection in Azure DevOps organization AzDoCompany for project AzureDeployment.
    }
    .NOTES
    PAT token needs permissions for Service Connections: Read, query, & manage
    Minimum permissions for Azure account:
    - Azure Application administrator
    - Owner on the resourcegroup or subscription that is scoped.
    Created by Barbara Forbes
    https://4bes.nl
    
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$AzServicePrincipalName,

        [parameter(Mandatory = $true)]
        [string]$AzSubscriptionName,

        [parameter(Mandatory = $false)]
        [string]$AzResourceGroupScope,

        [parameter(Mandatory = $false)]
        [string]$AzRole = "Contributor",

        [parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$AzDoOrganizationName,

        [parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$AzDoProjectName,

        [parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [string]$AzDoConnectionName,

        [parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [string]$AzDoUserName,

        [parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$AzDoToken
    )

    Write-Host "Starting Function New-AzDoServiceConnection"
    
    # Create the header to authenticate to Azure DevOps
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $AzDoUserName, $AzDoToken)))
    $Header = @{
        Authorization = ("Basic {0}" -f $base64AuthInfo)
    }
    Remove-Variable AzDoToken

    $AzSubscriptionID = az account show --query id --output tsv
    $TenantId = az account show --query tenantId --output tsv

    $Scope = "/subscriptions/$AzSubscriptionID/resourceGroups/$AzResourceGroupScope"


    Write-Host "Scope set: $Scope"
    # Create the Service Principal
    Try {
        $Parameters = @{
            DisplayName = $AzServicePrincipalName
            Role        = $AzRole
            Scope       = $Scope
            ErrorAction = "Stop"
        }
        $ServicePrincipal = az ad sp create-for-rbac --name $AzServicePrincipalName --role $AzRole --scopes $Scope
        Write-Host "Created ServicePrincipal $ServicePrincipal"
    }
    Catch {
        Throw "Could not create the ServicePrincipal: $_"
    }

    ## Get ProjectId
    $URL = "https://dev.azure.com/$AzDoOrganizationName/_apis/projects?api-version=6.0"
    Try {
        $AzDoProjectNameproperties = (Invoke-RestMethod $URL -Headers $Header -ErrorAction Stop).Value
        Write-Host "Collected Azure DevOps Projects"
    }
    Catch {
        if ($_ | Select-String -Pattern "Access Denied: The Personal Access Token used has expired.") {
            Throw "Access Denied: The Azure DevOps Personal Access Token used has expired."
        }
        else {
            $ErrorMessage = $_ | ConvertFrom-Json
            Throw "Could not collect project: $($ErrorMessage.message)"
        }
    }
    $AzDoProjectID = ($AzDoProjectNameproperties | Where-Object { $_.Name -eq $AzDoProjectName }).id
    Write-Host "Collected ID: $AzDoProjectID"

    if (-not $AzDoConnectionName) {
        $AzDoConnectionName = $AzResourceGroupScope -replace " "
    }

    # Create body for the API call
    $Body = @{
        data                             = @{
            subscriptionId   = $AzSubscriptionID
            subscriptionName = $AzSubscriptionName
            environment      = "AzureCloud"
            scopeLevel       = "Subscription"
            creationMode     = "Manual"
        }
        name                             = ($AzResourceGroupScope -replace " ")
        type                             = "AzureRM"
        url                              = "https://management.azure.com/"
        authorization                    = @{
            parameters = @{
                tenantid            = $env:tenantId
                serviceprincipalid  = $env:servicePrincipalId
                authenticationType  = "spnKey"
                serviceprincipalkey = $env:servicePrincipalKey
            }
            scheme     = "ServicePrincipal"
        }
        isShared                         = $false
        isReady                          = $true
        serviceEndpointProjectReferences = @(
            @{
                projectReference = @{
                    id   = $AzDoProjectID
                    name = $AzDoProjectName
                }
                name             = $AzDoConnectionName
            }
        )
    }

    $URL = "https://dev.azure.com/$AzDoOrganizationName/$AzDoProjectName/_apis/serviceendpoint/endpoints?api-version=6.0-preview.4"
    $Parameters = @{
        Uri         = $URL
        Method      = "POST"
        Body        = ($Body | ConvertTo-Json -Depth 3)
        Headers     = $Header
        ContentType = "application/json"
        Erroraction = "Stop"
    }
    try {
        Write-Host "Creating Connection"
        $Result = Invoke-RestMethod @Parameters
    }
    Catch {
        $ErrorMessage = $_ | ConvertFrom-Json
        Throw "Could not create Connection: $($ErrorMessage.message)"
    }
    Write-Host "Connection Created"
    $Result
}