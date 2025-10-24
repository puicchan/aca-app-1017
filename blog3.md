# Build Once, Deploy Everywhere with Azure Container Apps and Layered Infrastructure

Azure Developer CLI v1.20.0 introduces separated container operations and layered infrastructure for deploying the same containerized application across multiple environments. This post demonstrates these capabilities using Azure Container Apps.

This is the third installment in our Azure Developer CLI series, following [Azure Developer CLI: From Dev to Prod with One Click](https://devblogs.microsoft.com/devops/azure-developer-cli-from-dev-to-prod-with-one-click/) and [Azure Developer CLI: From Dev to Prod with Azure DevOps Pipelines](https://devblogs.microsoft.com/devops/azure-developer-cli-from-dev-to-prod-with-azure-devops-pipelines/).

## Build Once, Deploy Everywhere

### The Challenge: Bundled Deployment Limitations

Before v1.20.0, `azd deploy` bundled container building, pushing to container registry, and deployment into a single operation for Azure Container App (ACA). This created limitations for production requirements:

- **Centralized Container Management**: Using a single Azure Container Registry (ACR) across multiple environments
- **Separated CI/CD Concerns**: Building containers once and deploying to multiple environments without rebuilding
- **Security Controls**: Deploying specific, pre-approved container versions to production
- **Deployment Flexibility**: Deploying the same container image to different environments with varying configurations

### The Solution: Separated Concerns and Layered Infrastructure

Azure Developer CLI v1.20.0 introduces two new capabilities:

#### 1. **Separated Container Operations**
- **`azd publish`**: Builds and pushes containers to a registry
- **`azd deploy --from-package`**: Deploys specific container versions to environments

#### 2. **Layered Infrastructure (Alpha)**
- Sequential deployment of infrastructure layers with dependency management
- Shared resources (like ACR) deployed independently of environment-specific resources
- Outputs from one layer flow to subsequent layers

Here's a [Flask application example](https://github.com/placeholder) migrated from Azure App Service to Azure Container Apps.

## Sample Application Architecture

### Application Overview

Our sample application is a Flask-based File Manager:

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

Here's how the sequence is defined in the `azure.yaml` file:

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

The layered approach solves the "chicken-and-egg" problem in container deployments. Both dev and prod share the same ACR. While we can skip the shared-acr layer by checking if an ACR endpoint is provided, the prod Container App needs ACR permissions. However, you can't assign permissions until both resources exist. Provisioning the resources sequentially ensures that ACR role assignment is completed before creating the prod Container App.

In summary:
1. **Foundation layer**: Creates the core resources depending on the `AZURE_ENV_TYPE` environment variable. Container Apps Environment and Managed Identity are also created in this layer.
2. **Shared ACR layer**: Creates a centralized container registry if no existing ACR endpoint is provided.  
3. **ACR Role Assignment layer**: Grants the Managed Identity permission to push to/pull from ACR depending on env type (dev gets push+pull, prod gets pull only).
4. **Container App layer**: Deploys the application (now has proper ACR access)

Each layer outputs critical information (resource IDs, endpoints) that subsequent layers automatically receive as input parameters.

For example, check `infra/acr-role/main.parameters.json` - you'll see `AZURE_CONTAINER_REGISTRY_NAME` flowing from the shared-acr layer to the ACR role assignment layer:

  ```
      "AZURE_CONTAINER_REGISTRY_NAME": {
      "value": "${AZURE_CONTAINER_REGISTRY_NAME}"` 
  ```

## Try it out

> ⚠️ **Important: Production Best Practices**  
> This post demonstrates capabilities available in Azure Developer CLI, including local deployment options. However, **we strongly recommend using CI/CD pipelines for all production deployments**. The local `azd up` workflow shown here is intended for rapid prototyping, initial setup, and development environments only.

### Prerequisites

- Azure Developer CLI v1.20.0 or later ([download here](https://aka.ms/azd-install))
- Docker (for local container testing)

### 1. Clone the Sample Repository

```bash
azd init -t https://github.com/[PLACEHOLDER-ORG]/[PLACEHOLDER_APP]
```

### 2. Provision and deploy the Development Environment

Creating and deploying to a development environment uses the familiar `azd up` workflow:

```bash
# Enable alpha feature for layered infrastructure
azd config set alpha.layers on

# Create and configure development environment
azd env new myapp-dev
azd env set AZURE_ENV_TYPE dev

# Deploy everything: infrastructure + build + push + deploy
azd up
```

### 3. Set Up Production Infrastructure

Since you're still working in dev mode, you'll want to prepare your production environment infrastructure. This is a one-time setup step that happens before implementing CI/CD pipelines:

```bash
# Create production environment
azd env new myapp-prod
azd env set AZURE_ENV_TYPE prod

# Reference existing shared ACR (replace with actual values from dev deployment)
azd env set ACR_RESOURCE_GROUP_NAME rg-shared-acr-resource-group-name
azd env set AZURE_CONTAINER_REGISTRY_ENDPOINT shared-acr-endpoint

# Provision infrastructure only (no build/push/deploy)
azd provision
```

> ⚠️ **Critical Infrastructure Best Practice**  
> - We use `azd provision` locally BEFORE going live to set up the infrastructure. **In CI/CD pipelines, we should NEVER run `azd provision`** - only `azd deploy`. Infrastructure changes in production can have serious ramifications and should go through a separate approval process. Accidental infrastructure modifications can cause outages or security issues. 
> - When `envType = 'prod'`, the infrastructure automatically includes VNET integration. For demonstration purposes (ease of testing), the current setup (line 42 in `aca-environment.bicep`) uses `internal: false`, which means your app remains publicly accessible while the compute infrastructure is isolated. For fully private environments, you'd set `internal: true` and add a reverse proxy.

### 4. Set Up CI/CD Pipeline with GitHub Actions

Make a simple code change and commit it to see the pipeline in action.

For instance, modify the \<h1\> in `index.html` and then run:

```bash
# Select your dev environment and configure pipeline
azd env select myapp-dev
# Make sure you select GitHub as the pipeline provider.
azd pipeline config
```

1. **Watch GitHub Actions**: Navigate to your repository's Actions tab
2. **Monitor Build Stage**: See the container being built with a unique tag
3. **Automatic Dev Deployment**: Watch the container deploy to development automatically
4. **Verify Deployment**: Check both environments to confirm the same container is running

## The GitHub Actions Workflow

The workflow follows a three-stage pattern: **Build → Deploy-Dev → Deploy-Prod**

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Actions Workflow                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ Job 1: BUILD                                                    │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ 1. Enable alpha features (layered infrastructure)           │ │
│ │ 2. Set environment names (dev/prod)                         │ │
│ │ 3. Provision Infrastructure (dev environment)               │ │
│ │ 4. Build & Publish Container to ACR                         │ │
│ │    └─ azd publish app                                       │ │
│ │    └─ Get image: azd env get-value SERVICE_APP_IMAGE_NAME   │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ Outputs:                                                        │
│  • container-image: crXXXX.azurecr.io/app:azd-deploy-123456     │
│  • dev-env-name: myapp-dev                                      │
│  • prod-env-name: myapp-prod                                    │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│ Job 2: DEPLOY-DEV                                               │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ 1. Deploy to Development                                    │ │
│ │    └─ azd deploy app --from-package <container-image>       │ │
│ │ 2. Validate Application                                     │ │
│ │    └─ Run smoke tests, integration tests                    │ │
│ └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│ Job 3: DEPLOY-PROD                                              │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ 1. Deploy to Production                                     │ │
│ │    └─ azd deploy app --from-package <same container-image>  │ │
│ │ 2. Validate Production Deployment                           │ │
│ │    └─ Run health checks, performance tests                  │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

Key: Same container image (built once) deployed to both environments
```

For full details of the workflow implementation, refer to the complete [azure-dev.yml](<placeholder url>/.github/workflows/azure-dev.yml) file in the repository.

**Key Points:**
- The container is built **once** in the build stage
- `azd env get-value SERVICE_APP_IMAGE_NAME` retrieves the published image name
- Both dev and prod deploy the **exact same container image**
- Validation steps ensure quality gates between stages

> **Note:** This workflow uses GitHub Actions job outputs to pass the container image name between jobs. Job outputs are only available on GitHub-hosted runners. If you're using self-hosted runners, you'll need an alternative approach such as storing the image name in an artifact or using a different method to share data between jobs.

## Conclusion

This post demonstrates an approach to achieving "build once, deploy everywhere" patterns using Azure Container Apps with Azure Developer CLI v1.20.0. Following our previous explorations with Azure App Service, this Container Apps version showcases how the same principles apply across different Azure compute services.

The layered infrastructure approach and separated container operations (`azd publish` + `azd deploy --from-package`) provide a foundation for teams wanting to move beyond the convenience of `azd up` while maintaining the familiar azd developer experience.

**Key capabilities shown:**
- **Container Apps Integration**: How `azd` works with Azure Container Apps
- **Layered Infrastructure**: Sequential deployment patterns with dependency management
- **Environment Separation**: Development convenience with production-ready controls

We recognize that more sophisticated approaches exist depending on your organization's requirements. Whether you need advanced networking, complex compliance requirements, or different deployment strategies, the specific implementation will vary based on your team's needs.

The Azure Developer CLI team continues to explore and validate production deployment scenarios, ensuring that azd provides reliable patterns as your applications scale from development to production environments.

Questions about implementation? Join the discussion [here](https://github.com/azure/azure-dev/discussions/5447). 

*For more Azure Developer CLI content, follow the [Azure Developer CLI blog](https://devblogs.microsoft.com/azure-sdk/) and check out the [official documentation](https://aka.ms/azd-docs).*
