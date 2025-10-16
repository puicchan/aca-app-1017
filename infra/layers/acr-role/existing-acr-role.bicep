targetScope = 'subscription'

@description('Principal ID of the managed identity')
param principalId string

@description('ACR resource group name')
param acrResourceGroup string

@description('ACR name')
param acrName string

// Reference the existing resource group containing the ACR
resource existingRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: acrResourceGroup
}

// Deploy role assignment to the existing ACR's resource group
module roleAssignmentDeployment './acr-role-assignment.bicep' = {
  name: 'roleAssignmentDeployment'
  scope: existingRg
  params: {
    principalId: principalId
    containerRegistryName: acrName
  }
}

output roleAssignmentId string = roleAssignmentDeployment.outputs.roleAssignmentId
