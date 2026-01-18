// ==================================================
// App Service Deployment Identity Module
// ==================================================
// Description: Creates UAMI with federated credentials and assigns Website Contributor role
// Purpose: Complete CI/CD setup for App Service deployment via GitHub Actions
// Features:
//   - User-Assigned Managed Identity creation
//   - Federated credential for GitHub OIDC authentication
//   - Website Contributor role assignment to App Service
//   - Reusable for multiple services
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

@description('Name of the App Service to grant Website Contributor access to')
param appServiceName string

@description('Azure role definition GUID for Website Contributor')
param websiteContributorRoleId string

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
// EXISTING RESOURCES - APP SERVICE
// ==================================================

resource appService 'Microsoft.Web/sites@2025-03-01' existing = {
  name: appServiceName
}

// ==================================================
// RBAC ROLE ASSIGNMENT - WEBSITE CONTRIBUTOR
// ==================================================

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appService.id, managedIdentity.id, websiteContributorRoleId)
  scope: appService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', websiteContributorRoleId)
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    description: 'Allows CI/CD managed identity to deploy to ${appServiceName}'
  }
}

// ==================================================
// OUTPUTS
// ==================================================

@description('User-Assigned Managed Identity resource ID')
output managedIdentityId string = managedIdentity.id

@description('User-Assigned Managed Identity principal ID (Object ID)')
output managedIdentityPrincipalId string = managedIdentity.properties.principalId

@description('User-Assigned Managed Identity client ID')
output managedIdentityClientId string = managedIdentity.properties.clientId

@description('User-Assigned Managed Identity name')
output managedIdentityName string = managedIdentity.name

@description('Federated credential name')
output federatedCredentialName string = federatedCredential.name

@description('Federated credential subject')
output federatedCredentialSubject string = federatedCredential.properties.subject

@description('Role assignment ID')
output roleAssignmentId string = roleAssignment.id
