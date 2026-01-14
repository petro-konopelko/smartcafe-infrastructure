// ==================================================
// Key Vault RBAC Module
// ==================================================
// Description: Grants App Service managed identity access to Key Vault
// Components: RBAC role assignment for Key Vault Secrets User
// ==================================================

targetScope = 'resourceGroup'

// ==================================================
// PARAMETERS
// ==================================================

@description('Key Vault name')
param keyVaultName string

@description('App Service managed identity principal ID')
param appServicePrincipalId string

// ==================================================
// EXISTING RESOURCES
// ==================================================

resource keyVault 'Microsoft.KeyVault/vaults@2025-05-01' existing = {
  name: keyVaultName
}

// ==================================================
// RBAC ROLE ASSIGNMENTS
// ==================================================

// Grant App Service 'Key Vault Secrets User' role
resource secretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, appServicePrincipalId, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: appServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ==================================================
// OUTPUTS
// ==================================================

@description('Role assignment resource ID')
output roleAssignmentId string = secretsUserRoleAssignment.id
