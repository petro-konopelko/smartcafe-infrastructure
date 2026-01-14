// ==================================================
// PostgreSQL Flexible Server Module
// ==================================================
// Description: Creates Azure Database for PostgreSQL Flexible Server
// Components: PostgreSQL server, default database (private network only)
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

@description('PostgreSQL server name')
param serverName string

@description('Administrator login name')
@secure()
param administratorLogin string

@description('Administrator password')
@secure()
param administratorPassword string

@description('PostgreSQL SKU name')
param skuName string

@description('PostgreSQL SKU tier')
param skuTier string

@description('Storage size in GB')
param storageSizeGB int

@description('PostgreSQL version')
param version string

@description('Subnet ID for private networking')
param subnetId string

@description('Resource tags')
param tags ResourceTags

// Extract VNet ID from subnet ID
var vnetId = substring(subnetId, 0, lastIndexOf(subnetId, '/subnets/'))

// ==================================================
// PRIVATE DNS ZONE
// ==================================================

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: '${serverName}.private.postgres.database.azure.com'
  location: 'global'
  tags: tags
}

// Link Private DNS Zone to VNet
resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: '${serverName}-vnet-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

// ==================================================
// POSTGRESQL FLEXIBLE SERVER
// ==================================================

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2025-08-01' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    version: version
    storage: {
      storageSizeGB: storageSizeGB
      autoGrow: 'Disabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    network: {
      publicNetworkAccess: 'Disabled'
      delegatedSubnetResourceId: subnetId
      privateDnsZoneArmResourceId: privateDnsZone.id
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
    }
  }
}

// ==================================================
// OUTPUTS
// ==================================================

@description('PostgreSQL server resource ID')
output serverId string = postgresServer.id

@description('PostgreSQL server FQDN')
output serverFqdn string = postgresServer.properties.fullyQualifiedDomainName

@description('Private DNS Zone ID')
output privateDnsZoneId string = privateDnsZone.id
