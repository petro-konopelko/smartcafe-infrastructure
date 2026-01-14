// ==================================================
// Common Types - Azure Tags
// ==================================================
// Description: Standardized tag types for Azure resources
// ==================================================

@export()
type ResourceTags = {
  @description('Environment tag (e.g., development, staging, production)')
  Environment: string
  
  @description('Project name')
  Project: string
  
  @description('Managed by tool/service')
  ManagedBy: string
  
  @description('Deployed by tool/service')
  DeployedBy: string
}
