# Flask File Manager - Azure Container Apps

A containerized Flask web application that allows users to upload, list, and view files stored in Azure Blob Storage. The application is designed to run on Azure Container Apps with Managed Identity authentication.

![Screenshot](./screenshot.png)

## Architecture

- **Frontend**: Flask web application with HTML templates
- **Storage**: Azure Blob Storage for file storage
- **Authentication**: Azure Managed Identity (no keys required)
- **Hosting**: Azure Container Apps with auto-scaling
- **Infrastructure**: Azure Verified Modules (AVM) for best practices

## Features

- 📁 Upload text files through web interface
- 📋 List all uploaded files
- 👀 View file contents
- 🔒 Secure authentication using Managed Identity
- 🚀 Auto-scaling based on HTTP requests
- 📊 Integrated monitoring and logging

## Deployment to Azure

### Using Azure Developer CLI (azd)

This project uses **Azure Developer CLI v1.20.0+** with the alpha layered infrastructure feature for sequential deployment across multiple environments (dev/prod).

1. Install [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) v1.20.0 or later
2. Enable alpha features: `azd config set alpha.layers on`
3. Login: `azd auth login`
4. Initialize environment: `azd env new myapp-dev`
5. Deploy infrastructure and application: `azd up`

This will deploy resources in the following order:
1. **Foundation layer**: Virtual network, Log Analytics, Container App Environment
2. **Shared ACR layer**: Shared Azure Container Registry (if not exists)
3. **ACR role layer**: Grant container app pull permissions to shared ACR
4. **Container App layer**: Deploy the application container

## Project Structure

```
├── app/                          # Application code
│   └── templates/                # HTML templates
├── infra/                        # Infrastructure as code
│   ├── foundation/               # Layer 1: Network, Log Analytics, ACA Environment
│   ├── shared-acr/               # Layer 2: Shared Container Registry
│   ├── acr-role/                 # Layer 3: ACR role assignments
│   └── container-app/            # Layer 4: Container App + Storage
├── .github/workflows/            # CI/CD pipelines
│   └── azure-dev.yml             # Multi-environment deployment workflow
├── app.py                        # Main application
├── requirements.txt              # Python dependencies
├── Dockerfile                    # Container image definition
└── azure.yaml                    # Azure Developer CLI configuration
```
