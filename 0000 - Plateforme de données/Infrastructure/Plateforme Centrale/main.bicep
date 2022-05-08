param location string = resourceGroup().location
param tenantId string = subscription().tenantId

var keyVaultName = 'dp-principal-kv'


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
