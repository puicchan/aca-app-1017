// Container App Deployment Layer
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

@description('Existing ACR endpoint (optional)')
param existingAcrEndpoint string = ''

// Import outputs from foundation layer
param RESOURCE_GROUP_NAME string
param APP_IDENTITY_PRINCIPAL_ID string
param APP_IDENTITY_RESOURCE_ID string
param APP_IDENTITY_CLIENT_ID string
param AZURE_CONTAINER_APPS_ENVIRONMENT_ID string
param AZURE_STORAGE_ACCOUNT_NAME string
param AZURE_KEY_VAULT_URL string
param APPLICATION_INSIGHTS_CONNECTION_STRING string

// Import abbreviations
var abbrs = loadJsonContent('../../abbreviations.json')
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
    envType: envType
    containerAppsEnvironmentId: AZURE_CONTAINER_APPS_ENVIRONMENT_ID
    appIdentityPrincipalId: APP_IDENTITY_PRINCIPAL_ID
    appIdentityResourceId: APP_IDENTITY_RESOURCE_ID
    appIdentityClientId: APP_IDENTITY_CLIENT_ID
    storageAccountName: AZURE_STORAGE_ACCOUNT_NAME
    keyVaultUri: AZURE_KEY_VAULT_URL
    applicationInsightsConnectionString: APPLICATION_INSIGHTS_CONNECTION_STRING
    existingAcrEndpoint: existingAcrEndpoint
  }
}

// Outputs for azd integration
output SERVICE_APP_NAME string = containerApp.outputs.containerAppName
output SERVICE_APP_URI string = 'https://${containerApp.outputs.containerAppFqdn}'
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerApp.outputs.containerRegistryEndpoint
output AZURE_CONTAINER_REGISTRY_NAME string = containerApp.outputs.containerRegistryName
