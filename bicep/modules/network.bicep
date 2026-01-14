// ==================================================
// Network Module
// ==================================================
// Description: Creates VNet, subnets, and NSGs for SmartCafe infrastructure
// Components: VNet, App subnet (delegated), DB subnet (delegated), NSGs
// ==================================================

targetScope = 'resourceGroup'

// ==================================================
// TYPE IMPORTS
// ==================================================

import { ResourceTags } from '../types/tags.bicep'
import { NetworkAddresses } from '../types/network.bicep'

// ==================================================
// PARAMETERS
// ==================================================

@description('Azure region for resources')
param location string

@description('Virtual Network name')
param vnetName string

@description('Network address configuration')
param networkAddresses NetworkAddresses

@description('App Service subnet name')
param appSubnetName string

@description('Database subnet name')
param databaseSubnetName string

@description('App NSG name')
param appNsgName string

@description('Resource tags')
param tags ResourceTags

// ==================================================
// VIRTUAL NETWORK
// ==================================================

resource vnet 'Microsoft.Network/virtualNetworks@2025-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        networkAddresses.vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: appSubnetName
        properties: {
          addressPrefix: networkAddresses.appSubnetPrefix
          networkSecurityGroup: {
            id: appNsg.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
              locations: [
                location
              ]
            }
          ]
        }
      }
      {
        name: databaseSubnetName
        properties: {
          addressPrefix: networkAddresses.databaseSubnetPrefix
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// ==================================================
// NETWORK SECURITY GROUPS
// ==================================================

// NSG for App Service subnet
resource appNsg 'Microsoft.Network/networkSecurityGroups@2025-01-01' = {
  name: appNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'DenyInternetOutbound'
        properties: {
          description: 'Deny outbound traffic to internet'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Deny'
          priority: 4000
          direction: 'Outbound'
        }
      }
    ]
  }
}

// ==================================================
// OUTPUTS
// ==================================================

@description('Virtual Network resource ID')
output vnetId string = vnet.id

@description('App Service subnet resource ID')
output appSubnetId string = vnet.properties.subnets[0].id

@description('Database subnet resource ID')
output databaseSubnetId string = vnet.properties.subnets[1].id

@description('App NSG resource ID')
output appNsgId string = appNsg.id
