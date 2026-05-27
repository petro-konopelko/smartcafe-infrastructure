// ==================================================
// SmartCafe Production Environment Parameters
// ==================================================
// Description: Parameter file for production environment deployment
// Environment: Production
// Note: Secure parameters (postgresAdminLogin, postgresAdminPassword) 
//       must be provided via command line or pipeline
// ==================================================

using '../main.bicep'

// ==================================================
// ENVIRONMENT
// ==================================================

param environment = 'prod'

// ==================================================
// Azure Static Web Apps
// ==================================================

param staticWebAppSku = 'Standard'
param staticWebAppLocation = 'westeurope'

// ==================================================
// APP SERVICE
// ==================================================

param appServicePlanSku = 'P1v2'
param dotnetVersion = 'DOTNETCORE|10.0' // Used in appServiceConfigs array in main.bicep

// ==================================================
// POSTGRESQL
// ==================================================

param postgresSku = 'Standard_D4s_v3'
param postgresSkuTier = 'GeneralPurpose'
param postgresStorageSizeGB = 256
param postgresVersion = '18'

// Secure parameters - Override these via command line or GitHub secrets
param postgresAdminLogin = 'OVERRIDE_VIA_SECRETS'
param postgresAdminPassword = 'OVERRIDE_VIA_SECRETS'

// ==================================================
// NETWORKING
// ==================================================

param networkAddresses = {
  vnetAddressPrefix: '10.2.0.0/16'
  databaseSubnetPrefix: '10.2.1.0/26'
  appSubnetPrefix: '10.2.2.0/24'
  runnerSubnetPrefix: '10.2.3.0/27'
}
