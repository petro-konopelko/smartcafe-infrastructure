// ==================================================
// RBAC Assignment Type Definitions
// ==================================================
// Description: Separate type definitions for each resource type
// Purpose: Type-safe RBAC assignments with resource-specific modules
// Note: Role GUIDs loaded from bicep/variables/azure-roles.json in main.bicep
// ==================================================

// ==================================================
// SHARED UNION TYPES
// ==================================================

@description('Principal type - strictly typed to prevent misspellings')
@export()
type PrincipalType = 
  | 'ServicePrincipal' 
  | 'User' 
  | 'Group' 
  | 'Device' 
  | 'ForeignGroup'

@description('Storage assignment scope - account or sub-resource level')
@export()
type StorageScope = 
  | 'Account'           // Entire storage account
  | 'BlobContainer'     // Specific blob container
  | 'Table'             // Specific table
  | 'Queue'             // Specific queue
  | 'FileShare'         // Specific file share

// ==================================================
// KEY VAULT ROLE ASSIGNMENT TYPE
// ==================================================

@description('Key Vault role assignment - scoped to vault level')
@export()
type KeyVaultRoleAssignment = {
  @description('Name of the Key Vault to scope the assignment to')
  keyVaultName: string

  @description('Azure role definition GUID (use azureRoles.RoleName from main.bicep)')
  roleId: string

  @description('Principal ID (Object ID of the managed identity, user, or service principal)')
  principalId: string

  @description('Type of principal - strictly typed')
  principalType: PrincipalType

  @description('Optional description for the role assignment')
  description: string?
}

// ==================================================
// STORAGE ROLE ASSIGNMENT TYPE
// ==================================================

@description('Storage Account role assignment - supports account and sub-resource scoping')
@export()
type StorageRoleAssignment = {
  @description('Name of the Storage Account to scope the assignment to')
  storageAccountName: string

  @description('Azure role definition GUID (use azureRoles.RoleName from main.bicep)')
  roleId: string

  @description('Principal ID (Object ID of the managed identity, user, or service principal)')
  principalId: string

  @description('Type of principal - strictly typed')
  principalType: PrincipalType

  @description('Scope level for the assignment (default: Account)')
  scope: StorageScope?

  @description('Name of the sub-resource (blob container, table, queue, or file share name). Required if scope is not Account.')
  subResourceName: string?

  @description('Optional description for the role assignment')
  description: string?
}

// ==================================================
// APP SERVICE ROLE ASSIGNMENT TYPE
// ==================================================

@description('App Service role assignment - scoped to App Service level')
@export()
type AppServiceRoleAssignment = {
  @description('Name of the App Service to scope the assignment to')
  appServiceName: string

  @description('Azure role definition GUID (use azureRoles.RoleName from main.bicep)')
  roleId: string

  @description('Principal ID (Object ID of the managed identity, user, or service principal)')
  principalId: string

  @description('Type of principal - strictly typed')
  principalType: PrincipalType

  @description('Optional description for the role assignment')
  description: string?
}

// TODO: Add more resource-specific types as needed
// Example:
// @description('App Service role assignment')
// @export()
// type AppServiceRoleAssignment = {
//   name: string
//   appServiceName: string
//   roleId: string
//   principalId: string
//   principalType: PrincipalType
//   description: string?
// }
