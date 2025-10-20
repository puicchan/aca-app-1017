# Azure Developer CLI v1.20.0: Build Once, Deploy Everywhere with Azure Container Apps and Layered Infrastructure

Azure Developer CLI v1.20.0 introduces separated container operations and layered infrastructure for deploying the same containerized application across multiple environments. This post demonstrates these capabilities using Azure Container Apps.

This is the third installment in our Azure Developer CLI series, following [Azure Developer CLI: From Dev to Prod with One Click](https://devblogs.microsoft.com/devops/azure-developer-cli-from-dev-to-prod-with-one-click/) and [Azure Developer CLI: From Dev to Prod with Azure DevOps Pipelines](https://devblogs.microsoft.com/devops/azure-developer-cli-from-dev-to-prod-with-azure-devops-pipelines/).

> **Note**: While we demonstrate local deployment with `azd up`, **CI/CD pipelines remain the best practice for production deployments**.

## Build Once, Deploy Everywhere

### The Challenge: Bundled Deployment Limitations

Before v1.20.0, `azd deploy` bundled container building, pushing to container registry, and deployment into a single operation. This created limitations for production requirements:

- **Centralized Container Management**: Using a single Azure Container Registry (ACR) across multiple environments
- **Separated CI/CD Concerns**: Building containers once and deploying to multiple environments without rebuilding
- **Security Controls**: Deploying specific, pre-approved container versions to production
- **Deployment Flexibility**: Deploying the same container image to different environments with varying configurations

### The Solution: Separated Concerns and Layered Infrastructure

Azure Developer CLI v1.20.0 introduces two useful capabilities:

#### 1. **Separated Container Operations**
- **`azd publish`**: Builds and pushes containers to a registry
- **`azd deploy --from-package`**: Deploys specific container versions to environments

#### 2. **Layered Infrastructure (Alpha)**
- Sequential deployment of infrastructure layers with dependency management
- Shared resources (like ACR) deployed independently of environment-specific resources
- Outputs from one layer flow to subsequent layers

Here's a Flask application example migrated from Azure App Service to Azure Container Apps.

## Sample Application Architecture

### Application Overview

Our sample application is a Flask-based File Manager that shows practical container deployment patterns:

- **Core Functionality**: File upload, listing, and viewing with Azure Blob Storage backend
- **Security**: Azure Managed Identity integration (no stored connection strings)

### Infrastructure Architecture

The application uses a layered architecture that separates shared resources from environment-specific infrastructure:

```
┌─────────────────────────────────────────────────────────────────┐
│                     Shared Resources                            │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Resource Group: rg-acr-shared                               ││
│  │ ┌─────────────────────────────────────────────────────────┐ ││
│  │ │ Azure Container Registry (Basic SKU)                    │ ││
│  │ │ - Stores container images for all environments          │ ││
│  │ │ - Single source of truth for application containers     │ ││
│  │ └─────────────────────────────────────────────────────────┘ ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│                   Development Environment                       │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Resource Group: rg-dev-environment                          ││
│  │ ┌─────────────────────────────────────────────────────────┐ ││
│  │ │ Container Apps Environment                              │ ││
│  │ │ ┌─────────────────────────────────────────────────────┐ │ ││
│  │ │ │ Container App (Flask Application)                   │ │ ││
│  │ │ │ - Managed Identity for ACR access                   │ │ ││
│  │ │ │ - Auto-scaling enabled                              │ │ ││
│  │ │ └─────────────────────────────────────────────────────┘ │ ││
│  │ └─────────────────────────────────────────────────────────┘ ││
│  │ Azure Storage Account | Key Vault | Application Insights    ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│                  Production Environment                         │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Resource Group: rg-prod-environment                         ││
│  │ ┌─────────────────────────────────────────────────────────┐ ││
│  │ │ Container Apps Environment (VNET-integrated)            │ ││
│  │ │ ┌─────────────────────────────────────────────────────┐ │ ││
│  │ │ │ Container App (Same Image as Dev)                   │ │ ││
│  │ │ │ - Enhanced security configuration                   │ │ ││
│  │ │ │ - Production-grade scaling rules                    │ │ ││
│  │ │ └─────────────────────────────────────────────────────┘ │ ││
│  │ └─────────────────────────────────────────────────────────┘ ││
│  │ VNET | Storage | Key Vault | App Insights | Monitoring      ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### Layered Infrastructure Configuration

The `azure.yaml` file defines our layered deployment strategy:

```yaml
# Azure Container Apps Demo: "Build Once, Deploy Everywhere" with Shared ACR
name: dev-prod

# Layered Infrastructure Deployment Strategy
infra:
  layers:
    # Layer 1: Foundation - Core infrastructure for each environment
    - name: foundation
      path: infra/foundation
    
    # Layer 2: Shared ACR - Single registry for all environments  
    - name: shared-acr
      path: infra/shared-acr
    
    # Layer 3: ACR Role Assignment - Security configuration
    - name: acr-role
      path: infra/acr-role
    
    # Layer 4: Container App - Application deployment
    - name: container-app
      path: infra/container-app

services:
  app:
    project: .
    host: containerapp
    language: python
```

### Key Technical Benefits

1. **Foundation Layer**: Environment-specific resources deployed first
2. **Shared ACR Layer**: Centralized container registry with access controls
3. **ACR Role Assignment Layer**: Security configuration for Container Apps ACR access
4. **Container App Layer**: Application deployment using pre-built images

**Behind the Scenes**: we use the **Container upsert strategy** - created if they don't exist, updated if they do. Managed Identity eliminates stored credentials.

## Getting Started: Local Development

> ⚠️ **Important: Production Best Practices**  
> This post demonstrates capabilities available in Azure Developer CLI, including local deployment options. However, **we strongly recommend using CI/CD pipelines for all production deployments**. The local `azd up` workflow shown here is intended for rapid prototyping, initial setup, and development environments only.

### Prerequisites

- Azure Developer CLI v1.20.0 or later ([download here](https://aka.ms/azd-install))
- Docker (for local container testing)

### 1. Clone the Sample Repository

```bash
git clone https://github.com/[PLACEHOLDER-ORG]/azure-dev-container-apps-layered-infra
cd azure-dev-container-apps-layered-infra
```

### 2. Provision and deploy the Development Environment

Creating and deploying to a development environment uses the familiar `azd up` workflow:

> **⚠️ Alpha Feature**: Layered infrastructure is in alpha. Enable it first.

```bash
# Enable alpha feature for layered infrastructure
azd config set alpha.layers on

# Create and configure development environment
azd env new myapp-dev
azd env set AZURE_ENV_TYPE dev

# Deploy everything: infrastructure + build + push + deploy
azd up
```

**What happens during `azd up`:**

1. **Infrastructure Provisioning**: Deploys all four layers sequentially
   - Foundation: Resource Group, Container Apps Environment, Managed Identity
   - Shared ACR: Creates Azure Container Registry if it doesn't exist
   - ACR Role Assignment: Configures secure access permissions
   - Container App Infrastructure: Prepares the hosting environment

2. **Container Operations**: 
   - Builds the Flask application container locally
   - Pushes the image to the newly created ACR
   - Deploys the Container App using the pushed image

3. **Configuration**: Sets up environment variables and managed identity authentication

### 3. Set Up Production Infrastructure

Since we are still in dev mode, you'll want to prepare your production environment infrastructure. This is a one-time setup step that happens before implementing CI/CD pipelines:

```bash
# Create production environment
azd env new myapp-prod
azd env set AZURE_ENV_TYPE prod

# Reference existing shared ACR (replace with actual values from dev deployment)
azd env set ACR_RESOURCE_GROUP_NAME rg-acr-4slfyefh
azd env set AZURE_CONTAINER_REGISTRY_ENDPOINT crwf3gxcqc6yad4.azurecr.io

# Provision infrastructure only (no build/push/deploy)
azd provision
```

> **🚨 Critical Infrastructure Best Practice**  
> Notice that for production, we use `azd provision` locally BEFORE going live to set up the infrastructure. **In CI/CD pipelines, we should NEVER run `azd provision`** - only `azd deploy`. 
>
> **Why this matters:**
> - Infrastructure changes in production can have serious ramifications
> - Application CI/CD pipelines should focus on deploying applications, not infrastructure changes
> - Infrastructure changes should go through separate approval processes
> - Accidental infrastructure modifications can cause outages or security issues
>
> **The proper flow:** Use `azd provision` locally or in a separate infrastructure pipeline before go-live, then use only `azd deploy` in your application CI/CD.

**What happens in production setup:**

1. **Shared Resource Reuse**: References the existing ACR from development
2. **Production-Specific Infrastructure**: Creates enhanced infrastructure with VNET integration
3. **Security Configuration**: Sets up production-grade monitoring and security
4. **Deployment Readiness**: Infrastructure is ready, but application deployment is deferred to CI/CD

#### 🔒 Private Networking in Production (VNET Integration)

When `envType = 'prod'`, the infrastructure automatically includes VNET integration:

**What gets created:**
- Virtual Network with dedicated subnets for Container Apps infrastructure
- Private DNS zones for secure service communication
- Network isolation while maintaining external access through Azure's load balancer

**Key difference from development:**
- **Development**: Uses Azure's default public networking
- **Production**: Container infrastructure runs in a private subnet

**Configuration note**: The current setup uses `internal: false`, which means your app remains publicly accessible while the compute infrastructure is isolated. For fully private environments, you'd set `internal: true` and add a reverse proxy.

### 4. Explore the Generated Infrastructure

The layered approach solves the "chicken-and-egg" problem in container deployments:

**Problem**: Container Apps needs ACR permissions, but you can't assign permissions until both resources exist.

**Solution - Sequential Layers**:
1. **Foundation layer**: Creates Container Apps Environment and Managed Identity
2. **Shared ACR layer**: Creates the container registry  
3. **ACR Role Assignment layer**: Grants the Managed Identity permission to pull from ACR
4. **Container App layer**: Deploys the application (now has proper ACR access)

**Key Mechanism**: Each layer outputs critical information (resource IDs, endpoints) that subsequent layers automatically receive as input parameters.

**Example**: Check `infra/acr-role/main.parameters.json` - you'll see `"principalId": "${foundation.outputs.managedIdentityPrincipalId}"` flowing from Foundation layer to ACR Role Assignment layer.

You can explore:
- **Azure Portal**: Review the created resource groups and resources
- **Bicep Templates**: Examine the infrastructure-as-code in the `infra/` directory
- **ACR Integration**: Check the Container Registry for your built images

## CI/CD Pipeline with GitHub Actions

The workflow demonstrates the "build once, deploy everywhere" pattern:

#### Build Stage (Shared)

```yaml
# Build job - creates reusable container image
build:
  runs-on: ubuntu-latest
  outputs:
    package-tag: ${{ steps.generate-tag.outputs.tag }}
  steps:
    - name: Generate Dynamic Tag
      id: generate-tag
      run: |
        # Generate unique, traceable tag
        GIT_SHA=$(git rev-parse --short HEAD)
        TIMESTAMP=$(date +%s)
        TAG="azd-deploy-${{ github.run_id }}-${GIT_SHA}-${TIMESTAMP}"
        echo "tag=${TAG}" >> $GITHUB_OUTPUT
        
    - name: Build and Push Container
      run: |
        azd package --output-path ./dist
        azd publish --package-path ./dist --tag ${{ steps.generate-tag.outputs.tag }}
```

#### Deploy Stage (Environment-Specific)

> **⚠️ Infrastructure Safety**: The CI/CD pipeline uses ONLY `azd deploy` commands, never `azd provision`. Infrastructure is provisioned separately before go-live.

```yaml
# Deploy to development environment
deploy-dev:
  needs: build
  runs-on: ubuntu-latest
  steps:
    - name: Deploy to Development
      run: |
        azd env select myapp-dev
        azd deploy app --from-package "${{ env.ACR_ENDPOINT }}/app:${{ needs.build.outputs.tag }}"

# Deploy to production (with approval gate)
deploy-prod:
  needs: [build, deploy-dev]
  if: ${{ github.event.inputs.deploy_to_prod == 'true' }}
  runs-on: ubuntu-latest
  steps:
    - name: Deploy to Production
      run: |
        azd env select myapp-prod
        azd deploy app --from-package "${{ env.ACR_ENDPOINT }}/app:${{ needs.build.outputs.tag }}"
```

### Key Differences: `azd publish` vs `azd up`

**Development:**
- **`azd up`**: All-in-one convenience for rapid iteration

**Production:**
- **`azd publish` + `azd deploy`**: Separated concerns with security reviews and deployment flexibility

**Workflow:**
- **Pre-go-live**: `azd provision` locally to set up production infrastructure
- **CI/CD**: Only `azd deploy --from-package` to deploy specific container versions

### Testing the CI/CD Pipeline

Make a simple code change and commit it to see the pipeline in action:

For instance, modify the \<h1\> in index.html. And then run:

```bash
# Select your dev environment and configure pipeline
azd env select myapp-dev
azd pipeline config
```

1. **Watch GitHub Actions**: Navigate to your repository's Actions tab
2. **Monitor Build Stage**: See the container being built with a unique tag
3. **Automatic Dev Deployment**: Watch the container deploy to development automatically
4. **Verify Deployment**: Check both environments to confirm the same container is running

## Conclusion

This post demonstrates one approach to achieving "build once, deploy everywhere" patterns using Azure Container Apps with Azure Developer CLI v1.20.0. Following our previous explorations with Azure App Service, this Container Apps version showcases how the same principles apply across different Azure compute services.

The layered infrastructure approach and separated container operations (`azd publish` + `azd deploy --from-package`) provide a foundation for teams wanting to move beyond the convenience of `azd up` while maintaining the familiar azd developer experience.

**Key capabilities shown:**
- **Container Apps Integration**: How azd works with Azure Container Apps
- **Layered Infrastructure**: Sequential deployment patterns with dependency management
- **Environment Separation**: Development convenience with production-ready controls

**Important Context:**
This represents one way to implement these patterns with Azure Container Apps. More sophisticated approaches exist depending on your organization's requirements. Whether you need advanced networking, complex compliance requirements, or different deployment strategies, the specific implementation will vary based on your team's needs.

The Azure Developer CLI team continues to explore and validate production deployment scenarios, ensuring that azd provides reliable patterns as your applications scale from development to production environments.

Questions about implementation? Join the discussion [here](https://github.com/azure/azure-dev/discussions/5447). 

*For more Azure Developer CLI content, follow the [Azure Developer CLI blog](https://devblogs.microsoft.com/azure-sdk/) and check out the [official documentation](https://aka.ms/azd-docs).*
