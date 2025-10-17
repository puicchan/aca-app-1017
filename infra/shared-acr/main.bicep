
// Shared ACR Layer: Deploys Azure Container Registry for multi-environment use
// Creates: Dedicated Resource Group + Azure Container Registry (Basic SKU)
// Purpose: Single ACR shared across dev/prod environments for "build once, deploy everywhere"
targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the shared ACR environment')
param acrEnvironmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('Existing ACR endpoint - if provided, skip ACR creation')
param existingAcrEndpoint string = ''

// Generate unique names for shared resources
var abbrs = loadJsonContent('../abbreviations.json')
var resourceToken = uniqueString(subscription().id, location, acrEnvironmentName)
var tags = { 
  'azd-env-name': acrEnvironmentName
  resourceType: 'shared-acr'
  purpose: 'build-once-deploy-everywhere'
}

// Only deploy if no existing ACR endpoint is provided
var shouldDeployAcr = existingAcrEndpoint == ''

// Create dedicated resource group for shared ACR (only if needed)
resource acrResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = if (shouldDeployAcr) {
  name: '${abbrs.resourcesResourceGroups}acr-${take(resourceToken, 8)}'
  location: location
  tags: union(tags, {
    managedBy: 'azd'
    deploymentPattern: 'shared-registry'
  })
}

// Deploy the shared ACR (only if no existing ACR endpoint provided)
module sharedAcr './shared-acr.bicep' = if (shouldDeployAcr) {
  scope: acrResourceGroup
  name: 'shared-acr'
  params: {
    location: location
    tags: tags
    principalId: principalId
    environmentName: acrEnvironmentName
  }
}

// Outputs - handle both new ACR and existing ACR scenarios
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = shouldDeployAcr ? sharedAcr!.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT : existingAcrEndpoint
output AZURE_CONTAINER_REGISTRY_NAME string = shouldDeployAcr ? sharedAcr!.outputs.AZURE_CONTAINER_REGISTRY_NAME : split(existingAcrEndpoint, '.')[0]
output AZURE_CONTAINER_REGISTRY_RESOURCE_ID string = shouldDeployAcr ? sharedAcr!.outputs.AZURE_CONTAINER_REGISTRY_RESOURCE_ID : ''
output ACR_RESOURCE_GROUP_NAME string = shouldDeployAcr ? acrResourceGroup!.name : ''
