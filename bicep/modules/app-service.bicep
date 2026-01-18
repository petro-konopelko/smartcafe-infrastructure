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
import { AppServiceConfig } from '../types/app-service.bicep'

// ==================================================
// PARAMETERS
// ==================================================

@description('Azure region for resources')
param location string

@description('App Service Plan name')
param appServicePlanName string

@description('App Service Plan SKU')
param skuName string

@description('Subnet ID for VNet integration')
param subnetId string

@description('Resource tags')
param tags ResourceTags

@description('Array of App Service configurations')
param appServices AppServiceConfig[]

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

resource appService 'Microsoft.Web/sites@2025-03-01' = [
  for (app, index) in appServices: {
    name: app.name
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
        linuxFxVersion: app.dotnetVersion
        alwaysOn: app.alwaysOn
        ftpsState: 'Disabled'
        minTlsVersion: '1.2'
        http20Enabled: false
        appSettings: app.appSettings
      }
    }
  }
]

// ==================================================
// OUTPUTS
// ==================================================

@description('App Service resource IDs in input sequence')
output appServiceIds array = [for (app, index) in appServices: appService[index].id]

@description('App Service names in input sequence')
output appServiceNames array = [for (app, index) in appServices: appService[index].name]

@description('App Service default hostnames in input sequence')
output appServiceHostnames array = [for (app, index) in appServices: appService[index].properties.defaultHostName]

@description('App Service URLs in input sequence')
output appServiceUrls array = [
  for (app, index) in appServices: 'https://${appService[index].properties.defaultHostName}'
]

@description('App Service Managed Identity Principal IDs in input sequence')
output appServicePrincipalIds array = [for (app, index) in appServices: appService[index].identity.principalId]

@description('App Service Plan resource ID')
output appServicePlanId string = appServicePlan.id

@description('Number of App Services created')
output appServiceCount int = length(appServices)
