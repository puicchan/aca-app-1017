// Container App Deployment Layer: Deploys the main application to Azure Container Apps
// Purpose: Creates Container App with ACR integration and managed identity authentication
targetScope = 'subscription'

@minLength(1)
@maxLength(64)  
@description('Name of the environment for deployment naming')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Existing ACR endpoint for container images')
param existingAcrEndpoint string = ''

// Foundation layer outputs
param RESOURCE_GROUP_NAME string
param APP_IDENTITY_RESOURCE_ID string
param APP_IDENTITY_CLIENT_ID string
param AZURE_CONTAINER_APPS_ENVIRONMENT_ID string
param AZURE_STORAGE_ACCOUNT_NAME string

// Generate unique names and common tags
var abbrs = loadJsonContent('../abbreviations.json')
var tags = { 'azd-env-name': environmentName }
var resourceToken = uniqueString(subscription().id, RESOURCE_GROUP_NAME, location)

// Reference the existing resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: RESOURCE_GROUP_NAME
}

// Deploy Container App with ACR configuration
module containerApp './aca-containerapp.bicep' = {
  scope: rg
  name: 'containerAppDeployment'
  params: {
    location: location
    tags: tags
    abbrs: abbrs
    resourceToken: resourceToken
    containerAppsEnvironmentId: AZURE_CONTAINER_APPS_ENVIRONMENT_ID
    appIdentityResourceId: APP_IDENTITY_RESOURCE_ID
    appIdentityClientId: APP_IDENTITY_CLIENT_ID
    existingAcrEndpoint: existingAcrEndpoint
    storageAccountName: AZURE_STORAGE_ACCOUNT_NAME
  }
}

// Outputs for azd integration
output SERVICE_APP_NAME string = containerApp.outputs.containerAppName
output SERVICE_APP_URI string = 'https://${containerApp.outputs.containerAppFqdn}'
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerApp.outputs.containerRegistryEndpoint
output AZURE_CONTAINER_REGISTRY_NAME string = containerApp.outputs.containerRegistryName
