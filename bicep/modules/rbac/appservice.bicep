// ==================================================
// App Service RBAC Assignment Module
// ==================================================
// Description: Assigns Azure RBAC roles to App Service resources
// Purpose: Type-safe RBAC management for App Service with resource-level scoping
// Features:
//   - Strictly-typed App Service assignments
//   - Resource-level scoping (least privilege principle)
//   - Array-based for multiple assignments
// ==================================================

targetScope = 'resourceGroup'

// ==================================================
// TYPE IMPORTS
// ==================================================

import { AppServiceRoleAssignment } from '../../types/rbac.bicep'

// ==================================================
// PARAMETERS
// ==================================================

@description('Array of App Service role assignments to create')
param roleAssignments AppServiceRoleAssignment[]

// ==================================================
// EXISTING RESOURCES - APP SERVICE
// ==================================================

// Reference existing App Service resources
resource appServices 'Microsoft.Web/sites@2025-03-01' existing = [for assignment in roleAssignments: {
  name: assignment.appServiceName
}]

// ==================================================
// RBAC ROLE ASSIGNMENTS - APP SERVICE
// ==================================================

resource appServiceRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (assignment, index) in roleAssignments: {
  name: guid(appServices[index].id, assignment.principalId, assignment.roleId)
  scope: appServices[index]
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

@description('Array of role assignment IDs')
output roleAssignmentIds array = [for (assignment, index) in roleAssignments: appServiceRoleAssignments[index].id]

@description('Array of role assignment names')
output roleAssignmentNames array = [for (assignment, index) in roleAssignments: appServiceRoleAssignments[index].name]
