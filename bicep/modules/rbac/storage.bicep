// ==================================================
// Storage Account RBAC Assignment Module
// ==================================================
// Description: Assigns Azure RBAC roles to Storage Account resources
// Purpose: Type-safe RBAC management for Storage with account and sub-resource scoping
// Features:
//   - Strictly-typed Storage assignments
//   - Account-level scoping (implemented)
//   - Sub-resource scoping for blob containers, tables, queues (documented, ready to implement)
// ==================================================

targetScope = 'resourceGroup'

// ==================================================
// TYPE IMPORTS
// ==================================================

import { StorageRoleAssignment } from '../../types/rbac.bicep'

// ==================================================
// PARAMETERS
// ==================================================

@description('Array of Storage Account role assignments to create')
param roleAssignments StorageRoleAssignment[]

// ==================================================
// EXISTING RESOURCES - STORAGE ACCOUNT
// ==================================================

// Reference existing Storage Account resources
resource storageAccounts 'Microsoft.Storage/storageAccounts@2023-05-01' existing = [for assignment in roleAssignments: {
  name: assignment.storageAccountName
}]

// TODO: Add existing resource references for sub-resource scoping:
// - Blob containers: Microsoft.Storage/storageAccounts/blobServices/containers
// - Tables: Microsoft.Storage/storageAccounts/tableServices/tables
// - Queues: Microsoft.Storage/storageAccounts/queueServices/queues
// - File shares: Microsoft.Storage/storageAccounts/fileServices/shares

// ==================================================
// RBAC ROLE ASSIGNMENTS - STORAGE ACCOUNT
// ==================================================

// Account-level assignments (default when scope is not specified or scope == 'Account')
resource storageAccountRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (assignment, index) in roleAssignments: {
  name: guid(storageAccounts[index].id, assignment.principalId, assignment.roleId)
  scope: storageAccounts[index]
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', assignment.roleId)
    principalId: assignment.principalId
    principalType: assignment.principalType
    description: assignment.?description
  }
}]

// TODO: Implement sub-resource scoping for Storage:
// - Filter roleAssignments by scope property
// - Create separate role assignment resources for each scope type:
//   * BlobContainer: scope to storageAccount::blobServices::container
//   * Table: scope to storageAccount::tableServices::table
//   * Queue: scope to storageAccount::queueServices::queue
//   * FileShare: scope to storageAccount::fileServices::share
// Example:
// var blobContainerAssignments = filter(roleAssignments, a => a.?scope == 'BlobContainer')
// resource blobContainerRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (assignment, index) in blobContainerAssignments: {
//   name: assignment.name
//   scope: storageAccount::blobServices::containers[assignment.?subResourceName]
//   properties: { ... }
// }]

// ==================================================
// OUTPUTS
// ==================================================

@description('Number of Storage role assignments created')
output assignmentCount int = length(roleAssignments)

@description('Array of Storage role assignment IDs')
output roleAssignmentIds array = [for (assignment, index) in roleAssignments: storageAccountRoleAssignments[index].id]

@description('Array of Storage Account names with assignments')
output storageAccountNames array = [for assignment in roleAssignments: assignment.storageAccountName]
