// ==================================================
// App Service Module
// ==================================================
// Description: Creates App Service Plan and App Service
// Components: Linux App Service Plan, .NET App Service, Managed Identity
// ==================================================

targetScope = 'resourceGroup'

// ==================================================
// TYPE IMPORTS
// ==================================================

import { ResourceTags } from '../types/tags.bicep'
import { EnvironmentConfig } from '../types/environment.bicep'

// ==================================================
// PARAMETERS
// ==================================================

@description('Azure region for resources')
param location string

@description('App Service Plan name')
param appServicePlanName string

@description('App Service name')
param appServiceName string

@description('App Service Plan SKU')
param skuName string

@description('.NET version')
param dotnetVersion string

@description('Subnet ID for VNet integration')
param subnetId string

@description('Environment-specific configuration object')
param environmentConfig EnvironmentConfig

@description('Resource tags')
param tags ResourceTags

@description('Enable Always On for the App Service')
param alwaysOn bool = false

// ==================================================
// APP SERVICE PLAN
// ==================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: skuName
  }
  properties: {
    reserved: true // Required for Linux
  }
}

// ==================================================
// APP SERVICE
// ==================================================

resource appService 'Microsoft.Web/sites@2025-03-01' = {
  name: appServiceName
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    virtualNetworkSubnetId: subnetId
    siteConfig: {
      linuxFxVersion: dotnetVersion
      alwaysOn: alwaysOn
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: false
      appSettings: [
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: environmentConfig.aspnetcoreEnvironment
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
}

// ==================================================
// OUTPUTS
// ==================================================

@description('App Service resource ID')
output appServiceId string = appService.id

@description('App Service name')
output appServiceName string = appService.name

@description('App Service default hostname')
output appServiceHostname string = appService.properties.defaultHostName

@description('App Service URL')
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'

@description('App Service Managed Identity Principal ID')
output appServicePrincipalId string = appService.identity.principalId

@description('App Service Plan resource ID')
output appServicePlanId string = appServicePlan.id
