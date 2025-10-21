// Shared Azure Container Registry - Basic SKU for multi-environment use
@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Environment name for unique resource naming')
param environmentName string

// Generate unique ACR name using environment for uniqueness
var abbrs = loadJsonContent('../abbreviations.json')
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location, environmentName)

// Azure Container Registry for shared use across environments
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: '${abbrs.containerRegistryRegistries}${resourceToken}'
  location: location
  tags: union(tags, { 
    purpose: 'shared-multi-environment-registry'
  })
  sku: {
    name: 'Basic' // Basic SKU - widely supported, cost-effective for demos
  }
  properties: {
    adminUserEnabled: false // Use managed identity authentication
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

// Outputs
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.name
output AZURE_CONTAINER_REGISTRY_RESOURCE_ID string = containerRegistry.id
