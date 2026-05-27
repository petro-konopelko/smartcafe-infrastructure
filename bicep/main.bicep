// ==================================================
// SmartCafe Infrastructure - Main Orchestrator
// ==================================================
// Description: Main Bicep template orchestrating all infrastructure components
// Environment: Dev/Staging/Prod configurable via parameters
// ==================================================

targetScope = 'resourceGroup'

// ==================================================
// TYPE IMPORTS
// ==================================================

import { NetworkAddresses } from './types/network.bicep'
import { ResourceTags } from './types/tags.bicep'
import { EnvironmentConfig } from './types/environment.bicep'
import { KeyVaultRoleAssignment, StorageRoleAssignment } from './types/rbac.bicep'
import { AppServiceConfig } from './types/app-service.bicep'

// ==================================================
// PARAMETERS
// ==================================================

@description('Environment name (dev, staging, prod)')
@allowed([
  'dev'
  'staging'
  'prod'
])
param environment string

// App Service Parameters
@description('App Service Plan SKU')
@allowed([
  'F1' // Free
  'B1' // Basic
  'S1' // Standard
  'P1v2' // Premium v2
])
param appServicePlanSku string

@description('.NET version for App Services')
param dotnetVersion string

@description('Azure Static Web App SKU')
param staticWebAppSku string

@description('Azure Static Web App location')
param staticWebAppLocation string

// PostgreSQL Parameters
@description('PostgreSQL administrator login name')
@secure()
param postgresAdminLogin string

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('PostgreSQL SKU name')
param postgresSku string

@description('PostgreSQL SKU tier')
param postgresSkuTier string

@description('PostgreSQL storage size in GB')
param postgresStorageSizeGB int

@description('PostgreSQL version')
@allowed([
  '16'
  '17'
  '18'
])
param postgresVersion string

@description('Network address configuration for VNet and subnets')
param networkAddresses NetworkAddresses

// ==================================================
// VARIABLES
// ==================================================

// Azure region (derived from resource group location)
var location = resourceGroup().location

// Load shared variables from JSON file
var shared = loadJsonContent('./variables/shared-variables.json')

// Project name from shared file
var projectName = shared.projectName

// Azure AD tenant ID
var tenantId = subscription().tenantId

// Environment configuration from shared file
var envConfig EnvironmentConfig = shared.environments[environment]

// Resource naming convention: {environment}-{resourceType}-{location}-{projectName}
var resourceNames = {
  vnet: '${environment}-vnet-${location}-${projectName}'
  appSubnet: '${environment}-app-subnet-${location}-${projectName}'
  dbSubnet: '${environment}-db-subnet-${location}-${projectName}'
  nsgApp: '${environment}-app-nsg-${location}-${projectName}'
  runnerSubnet: '${environment}-runner-subnet-${location}-${projectName}'
  runnerNsg: '${environment}-runner-nsg-${location}-${projectName}'
  adminClient: '${environment}-admin-client-swa-${staticWebAppLocation}-${projectName}'
  appServicePlan: '${environment}-asp-${location}-${projectName}'
  postgres: '${environment}-postgres-${location}-${projectName}'
  keyVault: take('${environment}-kv-${location}-sc', 24) // Key Vault names must be <= 24 chars
}

// Default tags
var tags ResourceTags = {
  Environment: envConfig.environmentTag
  Project: projectName
  ManagedBy: 'Bicep'
  DeployedBy: 'GitHub-Actions'
}

// ==================================================
// MODULE DEPLOYMENTS
// ==================================================

// 1. Network Infrastructure
module network 'modules/network.bicep' = {
  params: {
    location: location
    vnetName: resourceNames.vnet
    networkAddresses: networkAddresses
    appSubnetName: resourceNames.appSubnet
    databaseSubnetName: resourceNames.dbSubnet
    appNsgName: resourceNames.nsgApp
    runnerSubnetName: resourceNames.runnerSubnet
    runnerNsgName: resourceNames.runnerNsg
    tags: tags
  }
}

// 2. Key Vault
module keyVault 'modules/keyvault.bicep' = {
  params: {
    location: location
    keyVaultName: resourceNames.keyVault
    tenantId: tenantId
    appSubnetId: network.outputs.appSubnetId
    tags: tags
  }
}

// 3. Migration Identity (must precede postgres so outputs are available)
module migrationIdentity 'modules/migration-identity.bicep' = {
  params: {
    location: location
    managedIdentityName: '${environment}-uami-migration-${location}-${projectName}'
    tags: tags
    githubRepository: 'petro-konopelko/smartcafe-menu'
    githubEnvironment: environment
  }
}

// 4. PostgreSQL Flexible Server
module postgres 'modules/postgresql.bicep' = {
  params: {
    location: location
    serverName: resourceNames.postgres
    administratorLogin: postgresAdminLogin
    administratorPassword: postgresAdminPassword
    skuName: postgresSku
    skuTier: postgresSkuTier
    storageSizeGB: postgresStorageSizeGB
    version: postgresVersion
    subnetId: network.outputs.databaseSubnetId
    migrationUamiPrincipalId: migrationIdentity.outputs.principalId
    migrationUamiName: migrationIdentity.outputs.name
    tags: tags
  }
}

// 4. Admin Client - Azure Static Web App
resource adminClient 'Microsoft.Web/staticSites@2025-03-01' = {
  name: resourceNames.adminClient
  location: staticWebAppLocation
  tags: tags
  sku: {
    name: staticWebAppSku
    tier: staticWebAppSku
  }
  properties:{
    enterpriseGradeCdnStatus: 'Disabled'
    provider: 'GitHub'
  }
}

// 4. App Service (Plan + Web Apps)
// App Service configurations
var appSettings = [
  {
    name: 'DOTNET_ENVIRONMENT'
    value: envConfig.aspnetcoreEnvironment
  }
  {
    name: 'KeyVault__Uri'
    value: keyVault.outputs.keyVaultUri
  }
  {
    name: 'Cors__AllowedOrigins__AdminClient'
    value: 'https://${adminClient.properties.defaultHostname}'
  }
]

var appServiceConfigs AppServiceConfig[] = [
  {
    name: '${environment}-app-menu-${location}-${projectName}'
    dotnetVersion: dotnetVersion
    alwaysOn: appServicePlanSku != 'F1' // Free tier doesn't support Always On.
    appSettings: appSettings
  }
]

module appService 'modules/app-service.bicep' = {
  params: {
    location: location
    appServicePlanName: resourceNames.appServicePlan
    skuName: appServicePlanSku
    subnetId: network.outputs.appSubnetId
    tags: tags
    appServices: appServiceConfigs
  }
}

var menuAppServicePrincipalId = appService.outputs.appServicePrincipalIds[0]
var menuAppServiceName = appServiceConfigs[0].name

// ==================================================
// RBAC ROLE ASSIGNMENTS
// ==================================================

// Load Azure role definitions (role name -> GUID mapping)
var azureRoles = loadJsonContent('./variables/azure-roles.json')

// --- Key Vault RBAC ---
var keyVaultRbac KeyVaultRoleAssignment[] = [
  {
    keyVaultName: resourceNames.keyVault
    roleId: azureRoles.KeyVaultSecretsUser
    principalId: menuAppServicePrincipalId
    principalType: 'ServicePrincipal'
    description: 'Allows App Service to read secrets from Key Vault'
  }
  // Add more Key Vault assignments here...
]

module keyVaultRbacAssignments 'modules/rbac/keyvault.bicep' = {
  params: {
    roleAssignments: keyVaultRbac
  }
}

// --- Storage RBAC ---
var storageRbac StorageRoleAssignment[] = [
  // Example: Storage Account access (account-level, default scope)
  // {
  //   storageAccountName: 'mystorageaccount'
  //   roleId: azureRoles.StorageBlobDataContributor
  //   principalId: appService.outputs.appServicePrincipalIds[0]
  //   principalType: 'ServicePrincipal'
  //   // scope defaults to 'Account' (entire storage account)
  // }
  // Example: Storage blob container access (sub-resource scoping - TODO: implement in module)
  // {
  //   storageAccountName: 'mystorageaccount'
  //   scope: 'BlobContainer'
  //   subResourceName: 'mycontainer'
  //   roleId: azureRoles.StorageBlobDataContributor
  //   principalId: appService.outputs.appServicePrincipalIds[0]
  //   principalType: 'ServicePrincipal'
  // }
]

module storageRbacAssignments 'modules/rbac/storage.bicep' = if (length(storageRbac) > 0) {
  params: {
    roleAssignments: storageRbac
  }
}

// ==================================================
// MANAGED IDENTITY FOR CI/CD DEPLOYMENTS
// ==================================================

// Menu App - Managed Identity with GitHub federated credential and Website Contributor role
module menuAppDeploymentIdentity 'modules/appservice-deployment-identity.bicep' = {
  params: {
    location: location
    managedIdentityName: '${environment}-uami-menu-${location}-${projectName}'
    tags: tags
    githubRepository: 'petro-konopelko/smartcafe-menu'
    githubEnvironment: environment
    appServiceName: menuAppServiceName
    websiteContributorRoleId: azureRoles.WebsiteContributor
  }
}

// ==================================================
// OUTPUTS
// ==================================================

@description('Environment')
output environmentName string = environment

@description('Resource Group Location')
output location string = location

@description('Menu App Service default hostname')
output menuAppServiceHostname string = appService.outputs.appServiceHostnames[0]

@description('Menu App Service URL')
output menuAppServiceUrl string = appService.outputs.appServiceUrls[0]

@description('Menu App Service Managed Identity Principal ID')
output menuAppServicePrincipalId string = appService.outputs.appServicePrincipalIds[0]

@description('All App Service names')
output appServiceNames array = appService.outputs.appServiceNames

@description('All App Service URLs')
output appServiceUrls array = appService.outputs.appServiceUrls

@description('All App Service Principal IDs')
output appServicePrincipalIds array = appService.outputs.appServicePrincipalIds

@description('PostgreSQL database name')
output postgresResourceName string = resourceNames.postgres

@description('PostgreSQL server FQDN')
output postgresServerFqdn string = postgres.outputs.serverFqdn

@description('Key Vault name')
output keyVaultName string = resourceNames.keyVault

@description('Key Vault URI')
output keyVaultUri string = keyVault.outputs.keyVaultUri


@description('Menu App Deployment Identity - Principal ID')
output menuAppDeploymentIdentityPrincipalId string = menuAppDeploymentIdentity.outputs.managedIdentityPrincipalId

@description('Menu App Deployment Identity - Client ID')
output menuAppDeploymentIdentityClientId string = menuAppDeploymentIdentity.outputs.managedIdentityClientId

@description('Menu App Deployment Identity - Name')
output menuAppDeploymentIdentityName string = menuAppDeploymentIdentity.outputs.managedIdentityName

@description('Runner subnet resource ID — used by ACI migration job')
output runnerSubnetId string = network.outputs.runnerSubnetId

@description('Migration UAMI client ID — used by GitHub Actions OIDC token exchange for migrations')
output migrationUamiClientId string = migrationIdentity.outputs.clientId

@description('Migration UAMI name — display name of the Entra ID administrator on PostgreSQL')
output migrationUamiName string = migrationIdentity.outputs.name
