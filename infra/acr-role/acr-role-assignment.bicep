@description('Principal ID of the managed identity')
param principalId string

@description('Name of the container registry')
param containerRegistryName string

// Get reference to the existing ACR
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

// Grant AcrPull role to the managed identity
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, principalId, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = acrPullRoleAssignment.id
