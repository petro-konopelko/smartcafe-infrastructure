// ==================================================
// Key Vault Module
// ==================================================
// Description: Creates Azure Key Vault for storing secrets
// Components: Key Vault with soft-delete, access policies
// ==================================================

targetScope = 'resourceGroup'

// ==================================================
// TYPE IMPORTS
// ==================================================

import { ResourceTags } from '../types/tags.bicep'

// ==================================================
// PARAMETERS
// ==================================================

@description('Azure region for resources')
param location string

@description('Key Vault name (must be globally unique, 3-24 chars)')
@maxLength(24)
param keyVaultName string

@description('Azure AD tenant ID')
param tenantId string

@description('Application subnet resource ID for network rules')
param appSubnetId string

@description('Resource tags')
param tags ResourceTags

// ==================================================
// KEY VAULT
// ==================================================

resource keyVault 'Microsoft.KeyVault/vaults@2025-05-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enableRbacAuthorization: true // Use RBAC instead of access policies
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: appSubnetId
          ignoreMissingVnetServiceEndpoint: false
        }
      ]
    }
  }
}

// ==================================================
// OUTPUTS
// ==================================================

@description('Key Vault resource ID')
output keyVaultId string = keyVault.id

@description('Key Vault URI')
output keyVaultUri string = keyVault.properties.vaultUri
