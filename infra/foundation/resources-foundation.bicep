// Azure Container Apps Environment Resources
// This configuration deploys the complete Azure Container Apps infrastructure with environment-specific settings:
// 
// ALL ENVIRONMENTS:
// 1. Azure Monitor (Application Insights + Log Analytics) for observability
// 2. User-assigned managed identity for secure resource access
// 3. Key Vault for secrets management
// 4. Storage account with blob container for file uploads
// 5. Azure Container Apps environment with Container Registry
// 6. Container App with proper RBAC permissions
//
// PRODUCTION (envType = 'prod'):
// - Higher resource limits (CPU/Memory)
// - Multiple replicas for high availability
// - Enhanced monitoring and alerting
//
// DEVELOPMENT (envType != 'prod'):  
// - Lower resource limits for cost optimization
// - Single replica deployment
// - Basic monitoring configuration
//
// Security Features:
// - Managed identity authentication (no secrets/keys)
// - Private container registry access
// - Storage account with disabled public access keys
// - Key Vault integration for sensitive configuration

@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Environment type - determines resource sizing and configuration')
@allowed(['dev', 'test', 'prod'])
param envType string = 'dev'

@description('Principal ID for Key Vault access policies')
param principalId string = ''

@description('Principal type for Key Vault access policies')
@allowed(['User', 'ServicePrincipal'])
param principalType string = 'User'

@description('Existing Azure Container Registry endpoint (optional - if provided, will use existing ACR instead of creating new one)')
param existingAcrEndpoint string = ''

var abbrs = loadJsonContent('../abbreviations.json')
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location)

// Monitor application with Azure Monitor
module monitoring './monitoring.bicep' = {
  name: 'monitoringDeployment'
  params: {
    location: location
    tags: tags
    abbrs: abbrs
    resourceToken: resourceToken
  }
}

// User-assigned managed identity for the Container App
module appIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'appidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}app-${resourceToken}'
    location: location
    tags: union(tags, {
      Environment: envType
      ManagedBy: 'AzureVerifiedModules'
    })
  }
}

// Network infrastructure (VNet, subnets, private DNS) - Production only
module network './network.bicep' = {
  name: 'networkDeployment'
  params: {
    location: location
    tags: tags
    abbrs: abbrs
    resourceToken: resourceToken
    envType: envType // Pass envType to network module
  }
}

// Shared services including storage account
module shared './storage.bicep' = {
  name: 'sharedDeployment'
  params: {
    location: location
    tags: tags
    abbrs: abbrs
    resourceToken: resourceToken
    envType: envType
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
    privateDnsZoneStorageId: network.outputs.privateDnsZoneStorageId
    appIdentityPrincipalId: appIdentity.outputs.principalId
  }
}

// Key Vault for secrets management
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${abbrs.keyVaultVaults}${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enableRbacAuthorization: true
    accessPolicies: []
  }
}

// Grant Key Vault Secrets User role to the managed identity
resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(resourceGroup().id, keyVault.name, appIdentity.name, '4633458b-17de-408a-b874-0445c86b69e6')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: appIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant Key Vault Secrets Officer role to the deployment principal (if provided)
resource keyVaultDeploymentRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (principalId != '') {
  scope: keyVault
  name: guid(resourceGroup().id, keyVault.name, principalId, 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Key Vault Secrets Officer
    principalId: principalId
    principalType: principalType
  }
}

// Azure Container Apps Environment only (no Container App yet)
// Use shared ACR from previous layer if available, otherwise fall back to existing ACR endpoint
module acaEnvironment './aca-environment.bicep' = {
  name: 'acaEnvironmentDeployment'
  params: {
    location: location
    tags: tags
    abbrs: abbrs
    resourceToken: resourceToken
    envType: envType
    applicationInsightsConnectionString: monitoring.outputs.applicationInsightsConnectionString
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    vnetIntegrationSubnetId: network.outputs.vnetIntegrationSubnetId
    existingAcrEndpoint: existingAcrEndpoint != '' ? existingAcrEndpoint : ''
  }
}

// Outputs for azd integration and next layers
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = acaEnvironment.outputs.containerAppsEnvironmentName
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = acaEnvironment.outputs.containerAppsEnvironmentId
output AZURE_STORAGE_ACCOUNT_NAME string = shared.outputs.storageAccountName
output AZURE_STORAGE_CONTAINER_NAME string = 'uploads'
output AZURE_KEY_VAULT_URL string = keyVault.properties.vaultUri
output AZURE_KEY_VAULT_NAME string = keyVault.name
output APPLICATION_INSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output APPLICATIONINSIGHTS_NAME string = replace(monitoring.outputs.applicationInsightsResourceId, '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Insights/components/', '')
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output APP_IDENTITY_PRINCIPAL_ID string = appIdentity.outputs.principalId
output APP_IDENTITY_RESOURCE_ID string = appIdentity.outputs.resourceId
output APP_IDENTITY_CLIENT_ID string = appIdentity.outputs.clientId
output VNET_INTEGRATION_SUBNET_ID string = network.outputs.vnetIntegrationSubnetId
