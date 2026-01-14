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

@description('.NET version for the app')
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
  appService: '${environment}-app-${location}-${projectName}'
  postgres: '${environment}-postgres-${location}-${projectName}'
  keyVault: '${environment}-kv-${location}-sc' // Key Vault names must be <= 24 chars
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

// 4. App Service (Plan + Web App)
module appService 'modules/app-service.bicep' = {
  params: {
    location: location
    appServicePlanName: resourceNames.appServicePlan
    appServiceName: resourceNames.appService
    skuName: appServicePlanSku
    dotnetVersion: dotnetVersion
    subnetId: network.outputs.appSubnetId
    environmentConfig: envConfig
    tags: tags
  }
}

// 5. Grant App Service access to Key Vault
module keyVaultRbac 'modules/keyvault-rbac.bicep' = {
  params: {
    keyVaultName: resourceNames.keyVault
    appServicePrincipalId: appService.outputs.appServicePrincipalId
  }
}

// ==================================================
// OUTPUTS
// ==================================================

@description('Environment')
output environmentName string = environment

@description('Resource Group Location')
output location string = location

@description('App Service default hostname')
output appServiceHostname string = resourceNames.appService

@description('App Service URL')
output appServiceUrl string = appService.outputs.appServiceUrl

@description('App Service Managed Identity Principal ID')
output appServicePrincipalId string = appService.outputs.appServicePrincipalId


@description('PostgreSQL database name')
output postgresResourceName string = resourceNames.postgres

@description('PostgreSQL server FQDN')
output postgresServerFqdn string = postgres.outputs.serverFqdn


@description('Key Vault name')
output keyVaultName string = resourceNames.keyVault

@description('Key Vault URI')
output keyVaultUri string = keyVault.outputs.keyVaultUri
