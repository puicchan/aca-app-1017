// ACR Role Assignment Layer: Grants Container App managed identity access to shared ACR
// Purpose: Assigns AcrPull role to enable Container App to pull images from shared registry
targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment for deployment naming')
param environmentName string

@description('App identity principal ID from foundation layer')
param APP_IDENTITY_PRINCIPAL_ID string

@description('Shared ACR resource group name from shared-acr layer')
param ACR_RESOURCE_GROUP_NAME string

@description('Shared ACR name from shared-acr layer')
param AZURE_CONTAINER_REGISTRY_NAME string

@description('Environment type (dev/prod) to determine permissions')
param AZURE_ENV_TYPE string = 'dev'

// Assign AcrPull role to Container App managed identity
module acrRoleAssignment './acr-role-assignment.bicep' = {
  name: 'acr-role-${take(environmentName, 10)}'
  scope: resourceGroup(ACR_RESOURCE_GROUP_NAME)
  params: {
    principalId: APP_IDENTITY_PRINCIPAL_ID
    containerRegistryName: AZURE_CONTAINER_REGISTRY_NAME
    environmentType: AZURE_ENV_TYPE
  }
}

// Output for layer dependency management
output ACR_ROLE_ASSIGNED bool = true
