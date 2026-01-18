# RBAC Assignment System - Quick Reference

## Overview
Separate modules per resource type (KeyVault, Storage) with auto-generated GUID names and strict typing.

**Features:**
- ✅ Type-safe per resource
- ✅ Auto-generated assignment names
- ✅ Role lookup via `azureRoles.RoleName`
- ✅ Optional descriptions

## Quick Start

```bicep
import { KeyVaultRoleAssignment, StorageRoleAssignment, AppServiceRoleAssignment } from './types/rbac.bicep'

var azureRoles = loadJsonContent('./variables/azure-roles.json')

// --- Key Vault RBAC ---
var keyVaultRbac KeyVaultRoleAssignment[] = [
  {
    keyVaultName: 'my-keyvault'
    roleId: azureRoles.KeyVaultSecretsUser
    principalId: appService.outputs.appServicePrincipalIds[0]
    principalType: 'ServicePrincipal'
    description: 'App reads secrets'  // Optional
  }
]

module keyVaultRbacAssignments 'modules/rbac/keyvault.bicep' = {
  params: { roleAssignments: keyVaultRbac }
}

// --- Storage RBAC ---
var storageRbac StorageRoleAssignment[] = [
  {
    storageAccountName: 'mystorageaccount'
    roleId: azureRoles.StorageBlobDataContributor
    principalId: appService.outputs.appServicePrincipalIds[0]
    principalType: 'ServicePrincipal'
  }
]

module storageRbacAssignments 'modules/rbac/storage.bicep' = if (length(storageRbac) > 0) {
  params: { roleAssignments: storageRbac }
}

// --- App Service RBAC ---
var appServiceRbac AppServiceRoleAssignment[] = [
  {
    appServiceName: 'my-app-service'
    roleId: azureRoles.WebsiteContributor
    principalId: managedIdentity.outputs.managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    description: 'CI/CD identity deploys to App Service'  // Optional
  }
]

module appServiceRbacAssignments 'modules/rbac/appservice.bicep' = {
  params: { roleAssignments: appServiceRbac }
}
```

## Common Scenarios

### Scenario 1: App Service → Key Vault Secrets
```bicep
var keyVaultRbac KeyVaultRoleAssignment[] = [
  {
    keyVaultName: resourceNames.keyVault
    roleId: azureRoles.KeyVaultSecretsUser
    principalId: appService.outputs.appServicePrincipalIds[0]
    principalType: 'ServicePrincipal'
  }
]
```

### Scenario 2: App Service → Storage Blob Access
```bicep
var storageRbac StorageRoleAssignment[] = [
  {
    storageAccountName: resourceNames.storage
    roleId: azureRoles.StorageBlobDataContributor
    principalId: appService.outputs.appServicePrincipalIds[0]
    principalType: 'ServicePrincipal'
  }
]
```

### Scenario 3: Multiple App Services → Same Key Vault
```bicep
var keyVaultRbac KeyVaultRoleAssignment[] = [
  // First app service reads secrets
  {
    keyVaultName: resourceNames.keyVault
    roleId: azureRoles.KeyVaultSecretsUser
    principalId: appService.outputs.appServicePrincipalIds[0]
    principalType: 'ServicePrincipal'
  }
  // Second app service reads secrets
  {
    keyVaultName: resourceNames.keyVault
    roleId: azureRoles.KeyVaultSecretsUser
    principalId: appService.outputs.appServicePrincipalIds[1]
    principalType: 'ServicePrincipal'
  }
]
```

## Available Roles

Currently configured in `azure-roles.json`:

- **KeyVaultSecretsUser** - Read secrets from Key Vault
- **StorageBlobDataContributor** - Read/write storage blobs
- **WebsiteContributor** - Deploy and manage App Service resources

**Add new role:**
```json
// bicep/variables/azure-roles.json
{
  "KeyVaultSecretsUser": "4633458b-17de-408a-b874-0445c86b69e6",
  "StorageBlobDataContributor": "ba92f5b4-2d11-453d-a403-e96b0029c9fe",
  "YourNewRole": "guid-from-azure"
}
```

Find role GUIDs: `az role definition list --name "Role Name"`

## Type Reference

**PrincipalType (strict):** `ServicePrincipal` | `User` | `Group` | `Device` | `ForeignGroup`

**KeyVaultRoleAssignment:**
- `keyVaultName: string`
- `roleId: string`
- `principalId: string`
- `principalType: PrincipalType`
- `description?: string`

**StorageRoleAssignment:**
- `storageAccountName: string`
- `roleId: string`
- `principalId: string`
- `principalType: PrincipalType`
- `scope?: StorageScope` (defaults to `'Account'`)
- `subResourceName?: string` (required if scope ≠ `'Account'`)
- `description?: string`

**AppServiceRoleAssignment:**
- `appServiceName: string`
- `roleId: string`
- `principalId: string`
- `principalType: PrincipalType`
- `description?: string`

**StorageScope (strict):** `Account` | `BlobContainer` | `Table` | `Queue` | `FileShare`

## CI/CD Deployment Identity (Managed Identity + RBAC)

**Module:** `modules/appservice-deployment-identity.bicep`

Combined module that creates a User-Assigned Managed Identity with GitHub federated credentials and assigns Website Contributor role to an App Service.

**Use this for:** Setting up CI/CD deployments from GitHub Actions to App Service

**Example:**
```bicep
module menuAppDeploymentIdentity 'modules/appservice-deployment-identity.bicep' = {
  params: {
    location: location
    managedIdentityName: '${environment}-uami-menu-${location}-${projectName}'
    tags: tags
    githubRepository: 'petro-konopelko/smartcafe-menu'
    githubEnvironment: environment  // dev, staging, prod
    appServiceName: appServiceConfigs[0].name
    websiteContributorRoleId: azureRoles.WebsiteContributor
  }
}

// Outputs available:
// - managedIdentityPrincipalId
// - managedIdentityClientId  (use in GitHub Actions)
// - federatedCredentialSubject
```

**Features:**
- ✅ Creates User-Assigned Managed Identity
- ✅ Configures GitHub OIDC federated credential
- ✅ Assigns Website Contributor role to App Service
- ✅ Reusable for multiple services
- ✅ No secrets needed in GitHub Actions

**Reuse for new service:**
Just add another module instance with different app service name and GitHub repository.

## TODO: Storage Sub-Resource Scoping

**Status:** Type definitions ready, module implementation pending

**Current:** Only account-level Storage assignments work
**Planned:** Blob container, table, queue, file share level assignments

**Example (when implemented):**
```bicep
// Blob container level
{
  storageAccountName: 'mystorageaccount'
  scope: 'BlobContainer'
  subResourceName: 'uploads'
  roleId: azureRoles.StorageBlobDataContributor
  principalId: appService.outputs.appServicePrincipalIds[0]
  principalType: 'ServicePrincipal'
}
```

**Implementation needed in `rbac-storage.bicep`:**
1. Filter assignments by `scope` property
2. Add existing resource references for sub-resources:
   - `Microsoft.Storage/storageAccounts/blobServices/containers`
   - `Microsoft.Storage/storageAccounts/tableServices/tables`
   - `Microsoft.Storage/storageAccounts/queueServices/queues`
   - `Microsoft.Storage/storageAccounts/fileServices/shares`
3. Create separate role assignment resources per scope type
4. Scope assignments to sub-resources instead of account

## Adding New Resource Type

1. **Add type:** `bicep/types/rbac.bicep`
2. **Create module:** `bicep/modules/rbac/<resource>.bicep`
3. **Use in main:** Import type, declare array, call module

**Example template (following implemented AppService pattern):**
```bicep
// types/rbac.bicep
@export()
type <Resource>RoleAssignment = {
  <resource>Name: string
  roleId: string
  principalId: string
  principalType: PrincipalType
  description: string?
}

// modules/rbac/<resource>.bicep
import { <Resource>RoleAssignment } from '../../types/rbac.bicep'
param roleAssignments <Resource>RoleAssignment[]

resource resources 'Microsoft.<Provider>/<type>@<version>' existing = [for a in roleAssignments: {
  name: a.<resource>Name
}]

resource assignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (a, i) in roleAssignments: {
  name: guid(resources[i].id, a.principalId, a.roleId)
  scope: resources[i]
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', a.roleId)
    principalId: a.principalId
    principalType: a.principalType
    description: a.?description
  }
}]

// main.bicep
var <resource>Rbac <Resource>RoleAssignment[] = [...]
module <resource>RbacAssignments 'modules/rbac/<resource>.bicep' = {...}
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Type error | Check required properties for type |
| Role not found | Add to `azure-roles.json` |
| Principal not found | Ensure resource exists first |
| Empty array error | Use `if (length(array) > 0)` |
