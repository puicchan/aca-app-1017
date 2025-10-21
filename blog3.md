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

> **🚨 Critical Infrastructure Best Practice**  
> Notice: 
> - We use `azd provision` locally BEFORE going live to set up the infrastructure. **In CI/CD pipelines, we should NEVER run `azd provision`** - only `azd deploy`. Infrastructure changes in production can have serious ramifications and should go through a separate approval process. Accidental infrastructure modifications can cause outages or security issues. 
> - Also, when `envType = 'prod'`, the infrastructure automatically includes VNET integration. For demonstration purposes (ease of testing), the current setup (line 42 in `aca-environment.bicep`) uses `internal: false`, which means your app remains publicly accessible while the compute infrastructure is isolated. For fully private environments, you'd set `internal: true` and add a reverse proxy.

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

### Build Stage (Shared)

Build and publish once to the shared ACR:

```yaml
- name: Build and Package Application
     id: package
     run: |
       echo "📦 Building container image..."
       
       # Package application (builds container image)
       PACKAGE_OUTPUT=$(azd package app 2>&1)
       echo "$PACKAGE_OUTPUT"
          
       # Extract the Target Image from azd package output
       TARGET_IMAGE=$(echo "$PACKAGE_OUTPUT" | grep -E "Target Image:" | sed 's/.*Target Image: //' | tr -d '[:space:]')
          
       if [ -n "$TARGET_IMAGE" ]; then
         # Construct full container registry path
         REGISTRY_ENDPOINT="${{ needs.build.outputs.registry-endpoint }}"
         FULL_IMAGE="${REGISTRY_ENDPOINT}/${TARGET_IMAGE}"
         echo "🐳 Container image to publish: ${FULL_IMAGE}"
         echo "container-image=${FULL_IMAGE}" >> $GITHUB_OUTPUT
       else
         echo "❌ Could not extract Target Image from azd package output"
         echo "Package output was:"
         echo "$PACKAGE_OUTPUT"
         exit 1
        fi
          
          echo "✅ Application packaged successfully"

- name: Publish to Azure Container Registry
    id: publish
    run: |
      echo "🚀 Publishing container image to ACR..."
        
      # Publish container image to ACR and capture output
      PUBLISH_OUTPUT=$(azd publish app 2>&1)
      echo "$PUBLISH_OUTPUT"
          
      # Extract the actual published image from azd publish output
      # Look for patterns like "Published image: ..." or similar
       PUBLISHED_IMAGE=$(echo "$PUBLISH_OUTPUT" | grep -E "(Published|Target|Image).*:" | tail -1 | sed 's/.*: //' | tr -d '[:space:]')
          
       if [ -z "$PUBLISHED_IMAGE" ]; then
         # Fallback: get the latest tag from ACR
         echo "🔍 Getting latest published image from ACR..."
         REGISTRY_ENDPOINT="${{ needs.build.outputs.registry-endpoint }}"
         ACR_NAME=$(echo "${REGISTRY_ENDPOINT}" | cut -d'.' -f1)
         REPO_NAME="dev-prod/app-${{ needs.build.outputs.dev-env-name }}"
         LATEST_TAG=$(az acr repository show-tags --name "${ACR_NAME}" --repository "${REPO_NAME}" --orderby time_desc --output tsv | head -1)
         PUBLISHED_IMAGE="${REGISTRY_ENDPOINT}/${REPO_NAME}:${LATEST_TAG}"
       fi
          
       echo "🐳 Actually published image: ${PUBLISHED_IMAGE}"
       echo "published-image=${PUBLISHED_IMAGE}" >> $GITHUB_OUTPUT
       echo "✅ Container image published to ACR"
```

### Deploy Stage (Environment-Specific)

Deploy to prod by pulling the same image from the shared ACR:

```yaml
- name: Deploy to Development
     run: |
       echo "🚀 Deploying to development environment..."
       # Use the actually published container image
       PUBLISHED_IMAGE="${{ steps.publish.outputs.published-image }}"
       echo "📍 Deploying from published registry image: ${PUBLISHED_IMAGE}"
       
       # Deploy using the published image (no rebuild needed)
       azd deploy app --from-package "${PUBLISHED_IMAGE}" --no-prompt
       echo "✅ Development deployment completed"

# Deploy to production 
- name: Deploy to Production
     run: |
       echo "🚀 Deploying to production environment..."
       
       # Use the same container image that was validated in dev
       CONTAINER_IMAGE="${{ needs.deploy-dev.outputs.container-image }}"
       echo "📍 Deploying from published registry image: ${CONTAINER_IMAGE}"
       
       # Deploy using the same published image (build once, deploy everywhere)
       azd deploy app --from-package "${CONTAINER_IMAGE}" --no-prompt
       echo "✅ Production deployment completed successfully"
```

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
