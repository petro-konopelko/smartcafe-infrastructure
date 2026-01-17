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

// 3. PostgreSQL Flexible Server
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
    tags: tags
  }
}

// 4. App Service (Plan + Web Apps)
// App Service configurations
var appServiceConfigs AppServiceConfig[] = [
  {
    name: '${environment}-app-menu-${location}-${projectName}'
    dotnetVersion: dotnetVersion
    alwaysOn: appServicePlanSku != 'F1' // Free tier doesn't support Always On
  }
]

module appService 'modules/app-service.bicep' = {
  params: {
    location: location
    appServicePlanName: resourceNames.appServicePlan
    skuName: appServicePlanSku
    subnetId: network.outputs.appSubnetId
    environmentConfig: envConfig
    tags: tags
    appServices: appServiceConfigs
  }
}

var menuAppServicePrincipalId = appService.outputs.appServicePrincipalIds[0]

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

module keyVaultRbacAssignments 'modules/rbac-keyvault.bicep' = {
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

module storageRbacAssignments 'modules/rbac-storage.bicep' = if (length(storageRbac) > 0) {
  params: {
    roleAssignments: storageRbac
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
