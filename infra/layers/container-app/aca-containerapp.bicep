// Container App deployment module
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

@description('Container Apps Environment resource ID')
param containerAppsEnvironmentId string

@description('App identity principal ID')
param appIdentityPrincipalId string

@description('App identity resource ID')
param appIdentityResourceId string

@description('App identity client ID')
param appIdentityClientId string

@description('Storage account name')
param storageAccountName string

@description('Key Vault URI')
param keyVaultUri string

@description('Application Insights connection string')
param applicationInsightsConnectionString string

@description('Existing ACR endpoint (optional)')
param existingAcrEndpoint string = ''

// Create ACR for dev environments (when not using existing ACR)
module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.1' = if (existingAcrEndpoint == '') {
  name: 'containerRegistry'
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    acrAdminUserEnabled: false
    roleAssignments: [
      {
        principalId: appIdentityPrincipalId
        roleDefinitionIdOrName: 'AcrPull'
        principalType: 'ServicePrincipal'
      }
    ]
    tags: union(tags, { 
      Environment: envType
    })
  }
}

// Variables for ACR endpoint
var acrEndpoint = existingAcrEndpoint != '' ? existingAcrEndpoint : '${abbrs.containerRegistryRegistries}${resourceToken}.azurecr.io'
var acrName = existingAcrEndpoint != '' ? split(existingAcrEndpoint, '.')[0] : '${abbrs.containerRegistryRegistries}${resourceToken}'

// Container App
module containerApp 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'containerApp'
  params: {
    name: '${abbrs.appContainerApps}${resourceToken}'
    location: location
    environmentResourceId: containerAppsEnvironmentId
    managedIdentities: {
      userAssignedResourceIds: [appIdentityResourceId]
    }
    workloadProfileName: envType == 'prod' ? 'GeneralPurpose' : 'Consumption'
    scaleMinReplicas: envType == 'prod' ? 2 : 1
    scaleMaxReplicas: envType == 'prod' ? 10 : 3
    ingressTargetPort: 8000
    ingressExternal: true
    ingressTransport: 'http'
    registries: [
      {
        server: existingAcrEndpoint != '' ? existingAcrEndpoint : '${abbrs.containerRegistryRegistries}${resourceToken}.azurecr.io'
        identity: appIdentityResourceId
      }
    ]
    containers: [
      {
        name: 'main'
        image: 'mcr.microsoft.com/k8se/quickstart:latest' // Placeholder image, azd will replace this during deployment
        resources: {
          cpu: json(envType == 'prod' ? '1.0' : '0.5')
          memory: envType == 'prod' ? '2.0Gi' : '1.0Gi'
        }
        env: [
          {
            name: 'AZURE_CLIENT_ID'
            value: appIdentityClientId
          }
          {
            name: 'AZURE_STORAGE_ACCOUNT_NAME'
            value: storageAccountName
          }
          {
            name: 'AZURE_STORAGE_CONTAINER_NAME'
            value: 'uploads'
          }
          {
            name: 'AZURE_KEY_VAULT_URL'
            value: keyVaultUri
          }
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: applicationInsightsConnectionString
          }
        ]
      }
    ]
    tags: union(tags, { 
      'azd-service-name': 'app'
      Environment: envType
      ManagedBy: 'AzureVerifiedModules'
    })
  }
}

// Outputs
output containerAppName string = containerApp.outputs.name
output containerAppFqdn string = containerApp.outputs.fqdn
output containerAppResourceId string = containerApp.outputs.resourceId
output containerRegistryEndpoint string = acrEndpoint
output containerRegistryName string = acrName
