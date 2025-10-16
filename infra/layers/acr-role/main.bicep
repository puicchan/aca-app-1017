// ACR Role Assignment Layer
targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@description('Environment type (dev or prod)')
param azureEnvType string = 'dev'

@description('Existing ACR endpoint (optional)')
param existingAcrEndpoint string = ''

@description('Existing ACR resource group (optional)')
param existingAcrResourceGroup string = ''

// Import outputs from foundation layer (only needed for prod)
@description('App identity principal ID (only needed for prod environments)')
param APP_IDENTITY_PRINCIPAL_ID string = '00000000-0000-0000-0000-000000000000'

// Grant ACR Pull permissions to the managed identity for existing ACR (only for prod environments)
// Skip entirely for dev environments or when required parameters are not provided
module existingAcrRoleAssignment './existing-acr-role.bicep' = if (azureEnvType != 'dev' && existingAcrEndpoint != '' && existingAcrResourceGroup != '' && APP_IDENTITY_PRINCIPAL_ID != '00000000-0000-0000-0000-000000000000' && APP_IDENTITY_PRINCIPAL_ID != '') {
  name: 'existingAcrRoleAssignment'
  params: {
    principalId: APP_IDENTITY_PRINCIPAL_ID
    acrResourceGroup: existingAcrResourceGroup
    acrName: split(existingAcrEndpoint, '.')[0]
  }
}

// Output to confirm role assignment completion
output ACR_ROLE_ASSIGNED bool = azureEnvType == 'prod' && existingAcrEndpoint != '' && existingAcrResourceGroup != '' && APP_IDENTITY_PRINCIPAL_ID != ''
