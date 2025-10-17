// Container App deployment module
@description('The location used for all deployed resources')
param location string

@description('Tags that will be applied to all resources')
param tags object = {}

@description('Abbreviations for Azure resource naming')
param abbrs object

@description('Resource token for unique naming')
param resourceToken string

@description('Container Apps Environment resource ID')
param containerAppsEnvironmentId string

@description('App identity resource ID')
param appIdentityResourceId string

@description('App identity client ID')
param appIdentityClientId string

@description('Storage account name for application data')
param storageAccountName string

@description('Existing ACR endpoint (optional)')
param existingAcrEndpoint string = ''

// Use existing ACR from shared layer or environment variable
var acrEndpoint = existingAcrEndpoint != '' ? existingAcrEndpoint : 'placeholder.azurecr.io'
var acrName = existingAcrEndpoint != '' ? split(existingAcrEndpoint, '.')[0] : 'placeholder'

// Simplified Container App for faster deployment
module containerApp 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'containerApp'
  params: {
    name: '${abbrs.appContainerApps}${resourceToken}'
    location: location
    environmentResourceId: containerAppsEnvironmentId
    managedIdentities: {
      userAssignedResourceIds: [appIdentityResourceId]
    }
    registries: existingAcrEndpoint != '' ? [
      {
        server: existingAcrEndpoint
        identity: appIdentityResourceId  // Use full resource ID for managed identity
      }
    ] : []
    scaleMinReplicas: 1
    scaleMaxReplicas: 3
    ingressTargetPort: 8000
    ingressExternal: true
    ingressTransport: 'http'
    containers: [
      {
        name: 'main'
        image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' // Placeholder - azd will replace
        resources: {
          cpu: json('0.25')
          memory: '0.5Gi'
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
        ]
      }
    ]
    tags: union(tags, { 
      'azd-service-name': 'app'
    })
  }
}

// Outputs
output containerAppName string = containerApp.outputs.name
output containerAppFqdn string = containerApp.outputs.fqdn
output containerAppResourceId string = containerApp.outputs.resourceId
output containerRegistryEndpoint string = acrEndpoint
output containerRegistryName string = acrName
