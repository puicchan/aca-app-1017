# GitHub Workflow Configuration for Azure Container Apps

This document explains how to configure your GitHub repository to use the Azure Container Apps CI/CD pipeline with the "build once, deploy everywhere" pattern.

## Required GitHub Repository Variables

Configure these variables in your GitHub repository settings under **Settings > Secrets and variables > Actions > Variables**:

### Authentication Variables
- `AZURE_CLIENT_ID`: The client ID of your Azure service principal or managed identity
- `AZURE_TENANT_ID`: Your Azure AD tenant ID  
- `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID

### Environment Configuration
- `AZURE_ENV_NAME`: Base environment name (e.g., `a1017-dev` or `a1017-prod`)
  - The pipeline will automatically generate both dev and prod environment names
  - If you provide `a1017-dev`, it creates `a1017-dev` and `a1017-prod`
  - If you provide `a1017-prod`, it creates `a1017-dev` and `a1017-prod`
- `AZURE_LOCATION`: Azure region for deployment (e.g., `eastus2`, `westeurope`)

### Container Registry Configuration
- `AZURE_CONTAINER_REGISTRY_ENDPOINT`: Your shared ACR endpoint (e.g., `crwf3gxcqc6yad4.azurecr.io`)
- `ACR_RESOURCE_GROUP_NAME`: Resource group containing the shared ACR (e.g., `rg-acr-4slfyefh`)

## GitHub Environments

Create these environments in your repository under **Settings > Environments**:

### Development Environment
- **Name**: `development`
- **Protection rules**: None (deploys automatically on push to main)
- **Environment secrets**: None required (uses repository variables)

### Production Environment  
- **Name**: `production`
- **Protection rules**: 
  - ✅ Required reviewers (recommended)
  - ✅ Wait timer: 5 minutes (recommended)
  - ✅ Deployment branches: Only protected branches
- **Environment secrets**: None required (uses repository variables)

## Azure Service Principal Setup

If you haven't already set up federated credentials for GitHub Actions, follow these steps:

### 1. Create Service Principal
```bash
# Create service principal
az ad sp create-for-rbac --name "github-actions-aca-app" \
    --role "Contributor" \
    --scopes "/subscriptions/{subscription-id}" \
    --json-auth

# Note the appId, password, and tenant values
```

### 2. Configure Federated Credentials
```bash
# Add federated credential for main branch
az ad app federated-credential create \
    --id {app-id} \
    --parameters '{
        "name": "github-main-branch",
        "issuer": "https://token.actions.githubusercontent.com",
        "subject": "repo:puicchan/aca-app:ref:refs/heads/main",
        "description": "Main branch deployments",
        "audiences": ["api://AzureADTokenExchange"]
    }'

# Add federated credential for pull requests (optional)
az ad app federated-credential create \
    --id {app-id} \
    --parameters '{
        "name": "github-pr",
        "issuer": "https://token.actions.githubusercontent.com", 
        "subject": "repo:puicchan/aca-app:pull_request",
        "description": "Pull request deployments",
        "audiences": ["api://AzureADTokenExchange"]
    }'
```

## Pipeline Features

### Automatic Environment Management
- **Development**: Deploys automatically on every push to `main`
- **Production**: Deploys after dev validation (can be disabled via manual trigger)

### Dynamic Container Tagging
- Generates unique tags like `azd-deploy-1760722268` based on timestamp
- Same tag used across dev and prod for true "build once, deploy everywhere"

### Manual Workflow Triggers
The workflow supports manual execution with options:
- **Deploy to production**: Choose whether to deploy to prod after dev
- **Skip validation**: Skip validation tests in development

### Container Registry Integration
- Uses your shared ACR (`crwf3gxcqc6yad4.azurecr.io`)
- Images stored in format: `{registry}/dev-prod/app-{env-name}:{tag}`
- Example: `crwf3gxcqc6yad4.azurecr.io/dev-prod/app-a1017-dev:azd-deploy-1760722268`

### Health Checks
- Automatic health checks on `/health` endpoint
- Retries with exponential backoff
- Fails production deployment if health checks fail

## Usage Examples

### Deploying from Command Line (matches pipeline behavior)
```bash
# Build and deploy to dev
azd deploy app --from-package "crwf3gxcqc6yad4.azurecr.io/dev-prod/app-a1017-dev:azd-deploy-1760722268"

# Deploy same image to prod
azd env select a1017-prod
azd deploy app --from-package "crwf3gxcqc6yad4.azurecr.io/dev-prod/app-a1017-dev:azd-deploy-1760722268"
```

### Manual Workflow Trigger
1. Go to **Actions** tab in GitHub
2. Select **Azure Container Apps CI/CD Pipeline**
3. Click **Run workflow**
4. Choose options:
   - ✅ Deploy to production after dev validation
   - ❌ Skip validation tests in dev

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` are correct
   - Check federated credentials are configured for your repository

2. **Environment Not Found**
   - Ensure you've run `azd env new` and `azd up` locally first for both environments
   - Verify `AZURE_ENV_NAME` variable matches your local environment names

3. **Container Registry Access**
   - Verify `AZURE_CONTAINER_REGISTRY_ENDPOINT` is correct
   - Check ACR has proper RBAC permissions for your service principal
   - Ensure `ACR_RESOURCE_GROUP_NAME` is set correctly

4. **Deployment Failures**
   - Check Azure Container Apps logs in Azure Portal
   - Verify container port matches application listening port
   - Check managed identity has proper permissions to ACR and storage

### Getting Help
- Check the **Actions** tab for detailed workflow logs
- Review deployment summary in workflow output
- Use Azure Portal to inspect Container Apps and ACR resources