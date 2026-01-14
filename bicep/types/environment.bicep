// ==================================================
// Common Types - Environment Configuration
// ==================================================
// Description: Environment-specific configuration types
// ==================================================

@export()
type EnvironmentConfig = {
  @description('Azure resource tag value for environment')
  environmentTag: string
  
  @description('Human-readable environment display name')
  environmentDisplayName: string
  
  @description('ASP.NET Core ASPNETCORE_ENVIRONMENT setting')
  aspnetcoreEnvironment: string
  
  @description('Application Insights retention period in days')
  appInsightsRetention: int
}
