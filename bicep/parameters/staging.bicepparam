// ==================================================
// SmartCafe Staging Environment Parameters
// ==================================================
// Description: Parameter file for staging environment deployment
// Environment: Staging
// Note: Secure parameters (postgresAdminLogin, postgresAdminPassword) 
//       must be provided via command line or pipeline
// ==================================================

using '../main.bicep'

// ==================================================
// ENVIRONMENT
// ==================================================

param environment = 'staging'

// ==================================================
// Azure Static Web Apps
// ==================================================

param staticWebAppSku = 'Standard'

// ==================================================
// APP SERVICE
// ==================================================

param appServicePlanSku = 'S1'
param dotnetVersion = 'DOTNETCORE|10.0' // Used in appServiceConfigs array in main.bicep

// ==================================================
// POSTGRESQL
// ==================================================

param postgresSku = 'Standard_D2s_v3'
param postgresSkuTier = 'GeneralPurpose'
param postgresStorageSizeGB = 128
param postgresVersion = '18'

// Secure parameters - Override these via command line or GitHub secrets
param postgresAdminLogin = 'OVERRIDE_VIA_SECRETS'
param postgresAdminPassword = 'OVERRIDE_VIA_SECRETS'

// ==================================================
// NETWORKING
// ==================================================

param networkAddresses = {
  vnetAddressPrefix: '10.1.0.0/16'
  databaseSubnetPrefix: '10.1.1.0/26'
  appSubnetPrefix: '10.1.2.0/24'
}
