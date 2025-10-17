// Foundation Layer: Core infrastructure for Azure Container Apps
// Creates: Resource Group, Container Apps Environment, Managed Identity, Storage, Key Vault, App Insights
targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Type of environment (dev, test, prod)')
param envType string = 'dev'

@description('Id of the user or app to assign application roles')
param principalId string = ''

// Import abbreviations and set common tags
var abbrs = loadJsonContent('../abbreviations.json')
var tags = { 'azd-env-name': environmentName }

// Create resource group for environment resources
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Deploy core foundation resources
module foundation './resources-foundation.bicep' = {
  scope: rg
  name: 'foundation'
  params: {
    location: location
    tags: tags
    envType: envType
    principalId: principalId
    existingAcrEndpoint: '' // Not used in foundation - kept for compatibility
  }
}

// Outputs for next layers
output RESOURCE_GROUP_NAME string = rg.name
output APP_IDENTITY_PRINCIPAL_ID string = foundation.outputs.APP_IDENTITY_PRINCIPAL_ID
output APP_IDENTITY_RESOURCE_ID string = foundation.outputs.APP_IDENTITY_RESOURCE_ID
output APP_IDENTITY_CLIENT_ID string = foundation.outputs.APP_IDENTITY_CLIENT_ID
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = foundation.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_NAME
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = foundation.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_ID
output AZURE_STORAGE_ACCOUNT_NAME string = foundation.outputs.AZURE_STORAGE_ACCOUNT_NAME
output AZURE_KEY_VAULT_URL string = foundation.outputs.AZURE_KEY_VAULT_URL
output AZURE_KEY_VAULT_NAME string = foundation.outputs.AZURE_KEY_VAULT_NAME
output APPLICATION_INSIGHTS_CONNECTION_STRING string = foundation.outputs.APPLICATION_INSIGHTS_CONNECTION_STRING
output VNET_INTEGRATION_SUBNET_ID string = foundation.outputs.VNET_INTEGRATION_SUBNET_ID
