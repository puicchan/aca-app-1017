// Azure Container Apps Environment (without Container App)
@description('The location used for all deployed resources')
param location string

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Abbreviations for Azure resource naming')
param abbrs object

@description('Resource token for unique naming')
param resourceToken string

@description('Environment type')
param envType string

@description('Application Insights connection string')
param applicationInsightsConnectionString string

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceResourceId string

@description('VNet integration subnet ID')
param vnetIntegrationSubnetId string

@description('Existing ACR endpoint (will be provided by shared ACR layer)')
param existingAcrEndpoint string = ''

// Container Apps Environment
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.5.2' = {
  name: 'containerAppsEnvironment'
  params: {
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: union(tags, {
      Environment: envType
      ManagedBy: 'AzureVerifiedModules'
    })
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    daprAIConnectionString: applicationInsightsConnectionString
    infrastructureSubnetId: envType == 'prod' ? vnetIntegrationSubnetId : null
    internal: false // Set to false for external access (change to true for production security)
    zoneRedundant: false
    workloadProfiles: envType == 'prod' ? [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
      {
        name: 'GeneralPurpose'
        workloadProfileType: 'D4'
        minimumCount: 1
        maximumCount: 3
      }
    ] : [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

// Outputs
output containerAppsEnvironmentName string = containerAppsEnvironment.outputs.name
output containerAppsEnvironmentId string = containerAppsEnvironment.outputs.resourceId
