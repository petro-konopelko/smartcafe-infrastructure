// ==================================================
// Common Types - App Service Configuration
// ==================================================
// Description: Type definitions for App Service configuration
// ==================================================

@description('App Service configuration')
@export()
type AppServiceConfig = {
  @description('App Service name')
  name: string
  
  @description('.NET version (e.g., DOTNETCORE|9.0)')
  dotnetVersion: string
  
  @description('Enable Always On for the App Service')
  alwaysOn: bool?
}
