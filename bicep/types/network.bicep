// ==================================================
// Common Types - Network Configuration
// ==================================================
// Description: Network-related type definitions for SmartCafe infrastructure
// ==================================================

@export()
type NetworkAddresses = {
  @description('VNet address space (e.g., 10.0.0.0/16)')
  vnetAddressPrefix: string
  
  @description('Database subnet CIDR (e.g., 10.0.1.0/26)')
  databaseSubnetPrefix: string
  
  @description('App Service subnet CIDR (e.g., 10.0.2.0/24)')
  appSubnetPrefix: string
}
