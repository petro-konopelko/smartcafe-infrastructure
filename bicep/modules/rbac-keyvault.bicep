// ==================================================
// Key Vault RBAC Assignment Module
// ==================================================
// Description: Assigns Azure RBAC roles to Key Vault resources
// Purpose: Type-safe RBAC management for Key Vault with resource-level scoping
// Features:
//   - Strictly-typed KeyVault assignments
//   - Resource-level scoping (least privilege principle)
//   - Array-based for multiple assignments
// ==================================================

targetScope = 'resourceGroup'

// ==================================================
// TYPE IMPORTS
// ==================================================

import { KeyVaultRoleAssignment } from '../types/rbac.bicep'

// ==================================================
// PARAMETERS
// ==================================================

@description('Array of Key Vault role assignments to create')
param roleAssignments KeyVaultRoleAssignment[]

// ==================================================
// EXISTING RESOURCES - KEY VAULT
// ==================================================

// Reference existing Key Vault resources
resource keyVaults 'Microsoft.KeyVault/vaults@2025-05-01' existing = [for assignment in roleAssignments: {
  name: assignment.keyVaultName
}]

// ==================================================
// RBAC ROLE ASSIGNMENTS - KEY VAULT
// ==================================================

resource keyVaultRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (assignment, index) in roleAssignments: {
  name: guid(keyVaults[index].id, assignment.principalId, assignment.roleId)
  scope: keyVaults[index]
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', assignment.roleId)
    principalId: assignment.principalId
    principalType: assignment.principalType
    description: assignment.?description
  }
}]

// ==================================================
// OUTPUTS
// ==================================================

@description('Number of Key Vault role assignments created')
output assignmentCount int = length(roleAssignments)

@description('Array of Key Vault role assignment IDs')
output roleAssignmentIds array = [for (assignment, index) in roleAssignments: keyVaultRoleAssignments[index].id]

@description('Array of Key Vault names with assignments')
output keyVaultNames array = [for assignment in roleAssignments: assignment.keyVaultName]
