param location string = resourceGroup().location
param tenantId string = subscription().tenantId
param resourceGroupName string = resourceGroup().name

param environmentName string = 'dev'
param projectName string = ''
param devopsAccount string = 'monentreprise'


var devopsProjectName = 'dp-${projectName}'
var keyVaultName = 'dp-${toLower(projectName)}-${toLower(environmentName)}-kvt'
var lakeStorageAccountName = 'dp${toLower(projectName)}${toLower(environmentName)}adl'
var synapseName = 'dp-${toLower(projectName)}-${toLower(environmentName)}-synapse'

resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 90
    tenantId: tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    accessPolicies: [
    ]
  }
}

resource dataLakeStorage 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: lakeStorageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    isHnsEnabled: true
    accessTier: 'Hot'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}
var endpointDataLake = dataLakeStorage.properties.primaryEndpoints.dfs

resource dataLakeStorageDefault 'Microsoft.Storage/storageAccounts/blobServices@2021-04-01' = {
  parent: dataLakeStorage
  name: 'default'
}

resource dataLakeStorageDefaultLake 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  parent: dataLakeStorageDefault
  name: 'lake'
}

resource symbolicname 'Microsoft.Synapse/workspaces@2021-06-01-preview' = {
  name: synapseName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    azureADOnlyAuthentication: true
    defaultDataLakeStorage: {
      accountUrl: endpointDataLake
      filesystem: 'lake'
    }
    managedResourceGroupName: '${resourceGroupName}-managed'
    trustedServiceBypassEnabled: true
    workspaceRepositoryConfiguration: {
      accountName: devopsAccount
      collaborationBranch: 'main'
      projectName: devopsProjectName
      repositoryName: devopsProjectName
      rootFolder: '/SynapseWorkspace/'
      tenantId: tenantId
      type: 'WorkspaceVSTSConfiguration'
    }
  }
}
