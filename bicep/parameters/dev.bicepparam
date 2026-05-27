// ==================================================
// SmartCafe Development Environment Parameters
// ==================================================
// Description: Parameter file for dev environment deployment
// Environment: Development
// Note: Secure parameters (postgresAdminLogin, postgresAdminPassword) 
//       must be provided via command line or pipeline
// ==================================================

using '../main.bicep'

// ==================================================
// ENVIRONMENT
// ==================================================

param environment = 'dev'

// ==================================================
// Azure Static Web Apps
// ==================================================

param staticWebAppSku = 'Free'
param staticWebAppLocation = 'westeurope'

// ==================================================
// APP SERVICE
// ==================================================

param appServicePlanSku = 'B1'
param dotnetVersion = 'DOTNETCORE|10.0' // Used in appServiceConfigs array in main.bicep

// ==================================================
// POSTGRESQL
// ==================================================

param postgresSku = 'Standard_B1ms'
param postgresSkuTier = 'Burstable'
param postgresStorageSizeGB = 32
param postgresVersion = '18'

// Secure parameters - Override these via command line or GitHub secrets
// Example: --parameters postgresAdminLogin='admin' postgresAdminPassword='SecurePassword123!'
param postgresAdminLogin = 'OVERRIDE_VIA_SECRETS'
param postgresAdminPassword = 'OVERRIDE_VIA_SECRETS'

// ==================================================
// NETWORKING
// ==================================================

param networkAddresses = {
  vnetAddressPrefix: '10.0.0.0/16'
  databaseSubnetPrefix: '10.0.1.0/26'
  appSubnetPrefix: '10.0.2.0/24'
  runnerSubnetPrefix: '10.0.3.0/27'
}
