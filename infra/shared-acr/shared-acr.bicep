// Shared Azure Container Registry - Basic SKU for multi-environment use
@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Principal ID for ACR access policies')
param principalId string = ''

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

// Grant ACR Pull role to the deployment principal (if provided)
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (principalId != '') {
  scope: containerRegistry
  name: guid(resourceGroup().id, containerRegistry.name, principalId, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: principalId
    principalType: 'User'
  }
}

// Grant ACR Push role to the deployment principal (if provided) for CI/CD
resource acrPushRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (principalId != '') {
  scope: containerRegistry
  name: guid(resourceGroup().id, containerRegistry.name, principalId, '8311e382-0749-4cb8-b61a-304f252e45ec')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec') // AcrPush
    principalId: principalId
    principalType: 'User'
  }
}

// Outputs
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.name
output AZURE_CONTAINER_REGISTRY_RESOURCE_ID string = containerRegistry.id
