// ==================================================
// Migration Identity Module
// ==================================================
// Description: Creates UAMI with federated credentials for database migration execution
// Purpose: Enables passwordless PostgreSQL authentication via Managed Identity for CI/CD migration runners
// Features:
//   - User-Assigned Managed Identity creation
//   - Federated credential for GitHub OIDC authentication (scoped to environment)
//   - No role assignments — PostgreSQL Entra ID admin assignment is handled in postgresql.bicep
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

@description('Name of the User-Assigned Managed Identity')
param managedIdentityName string

@description('Resource tags')
param tags ResourceTags

@description('GitHub repository in format: owner/repo (e.g., petro-konopelko/smartcafe-menu)')
param githubRepository string

@description('GitHub environment name for federated credential (e.g., dev, staging, prod)')
param githubEnvironment string

// ==================================================
// USER-ASSIGNED MANAGED IDENTITY
// ==================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
  tags: tags
}

// ==================================================
// FEDERATED CREDENTIAL FOR GITHUB ACTIONS
// ==================================================

resource federatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  name: 'github-${githubEnvironment}'
  parent: managedIdentity
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${githubRepository}:environment:${githubEnvironment}'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

// ==================================================
// OUTPUTS
// ==================================================

@description('User-Assigned Managed Identity principal ID (Object ID) — used for PostgreSQL Entra ID admin assignment')
output principalId string = managedIdentity.properties.principalId

@description('User-Assigned Managed Identity client ID — used by GitHub Actions OIDC token exchange')
output clientId string = managedIdentity.properties.clientId

@description('User-Assigned Managed Identity name — used as PostgreSQL Entra ID admin display name')
output name string = managedIdentity.name
