# GitHub Actions CI/CD Setup

[![PR Validation](https://github.com/petro-konopelko/smartcafe-infrastructure/actions/workflows/pr.yml/badge.svg)](https://github.com/petro-konopelko/smartcafe-infrastructure/actions/workflows/pr.yml)
[![Main Branch Deployment](https://github.com/petro-konopelko/smartcafe-infrastructure/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/petro-konopelko/smartcafe-infrastructure/actions/workflows/ci.yml)

This directory contains GitHub Actions workflows for automated validation and deployment of Azure infrastructure using Bicep.

## Workflows

### 1. `pr.yml` - Pull Request Validation

**Trigger**: Pull request to `main` branch

**Steps**:
1. ✅ Validates Bicep syntax
2. ✅ Runs Bicep linter on all files
3. ✅ Validates parameter files (JSON)
4. ✅ Validates ARM template
5. 💬 Posts validation results as PR comment

**Note**: No deployment occurs; this is validation only.

### 2. `ci.yml` - Main Branch Deployment

**Trigger**: Push to `main` branch (after PR merge)

**Jobs**:
1. **Validate** - Same as PR validation
2. **Approval** - Awaits manual approval from repository owner
3. **Deploy** - Deploys infrastructure to Azure
4. **Notification** - Sends deployment status

**Features**:
- Manual approval step required before deployment
- Environment-specific deployments (dev, staging, prod)
- Displays deployment outputs (App Service URL, Database FQDN, Key Vault name)
- Automatic resource group creation

### 3. `bicep-validate.yml` - Reusable Validation Action

**Type**: Composite action for code reuse

Used by both `pr.yml` and `ci.yml` to keep validation logic DRY.

## Required GitHub Secrets

Configure these secrets in your repository settings (Settings → Secrets and variables → Actions):

### Azure Authentication (Federated Identity - Recommended)

```
AZURE_CLIENT_ID              # Service Principal Client ID
AZURE_TENANT_ID              # Azure AD Tenant ID
AZURE_SUBSCRIPTION_ID        # Azure Subscription ID
```

### Application Secrets

```
POSTGRES_ADMIN_LOGIN         # PostgreSQL administrator login (e.g., smartcafeadmin)
POSTGRES_ADMIN_PASSWORD      # PostgreSQL administrator password (strong, complex)
```

## Setup Instructions

### 1. Create Service Principal with Federated Identity

```powershell
# Set variables
$subscriptionId = "YOUR_SUBSCRIPTION_ID"
$appName = "smartcafe-github-actions"
$githubOrg = "petro-konopelko"
$githubRepo = "smartcafe-infrastructure"

# Create Service Principal
$sp = az ad sp create-for-rbac `
  --name $appName `
  --role "Contributor" `
  --scopes /subscriptions/$subscriptionId `
  --query "{clientId: appId, tenantId: tenant}" -o json | ConvertFrom-Json

# Create federated credential for main branch
az ad app federated-credential create `
  --id $sp.clientId `
  --parameters '{
    "name": "github-actions-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$githubOrg"'/'"$githubRepo"':ref:refs/heads/main",
    "description": "GitHub Actions for main branch deployments",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for pull requests
az ad app federated-credential create `
  --id $sp.clientId `
  --parameters '{
    "name": "github-actions-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$githubOrg"'/'"$githubRepo"':pull_request",
    "description": "GitHub Actions for PR validation",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Output credentials
Write-Host "✓ Service Principal created"
Write-Host ""
Write-Host "Add these to GitHub Secrets:"
Write-Host "AZURE_CLIENT_ID: $($sp.clientId)"
Write-Host "AZURE_TENANT_ID: $($sp.tenantId)"
Write-Host "AZURE_SUBSCRIPTION_ID: $subscriptionId"
```

### 2. Add Secrets to GitHub

1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. Create the following repository secrets:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`
   - `POSTGRES_ADMIN_LOGIN`
   - `POSTGRES_ADMIN_PASSWORD`

3. (Optional) Create environments for approval rules:
   - **Settings** → **Environments**
   - Create: `dev`, `staging`, `prod`
   - Add required reviewers for `prod`

### 3. Create Resource Groups

```powershell
# Create resource groups for each environment
$environments = @('dev', 'staging', 'prod')

foreach ($env in $environments) {
  $rgName = "rg-smartcafe-$env-westeu"
  az group create --name $rgName --location westeurope
  Write-Host "✓ Created: $rgName"
}
```

## Workflow Flow

```
┌─────────────────────────────────────────┐
│  Create Pull Request                    │
│  (changes to bicep/ folder)             │
└──────────────┬──────────────────────────┘
               │
               ▼
        ┌──────────────┐
        │ pr.yml       │  ← Validation only, no deployment
        │              │
        │ ✓ Lint       │
        │ ✓ Validate   │
        │ ✓ Comment PR │
        └──────┬───────┘
               │
               ▼
      ┌────────────────────┐
      │ Merge to main      │
      └────────┬───────────┘
               │
               ▼
        ┌──────────────┐
        │ ci.yml       │
        │              │
        │ 1. Validate  │
        │ 2. Await     │──────┐
        │    Approval  │      │
        │ 3. Deploy    │      │ Manual approval
        │ 4. Notify    │      │ required!
        │              │      │
        └──────────────┘      │
               ▲               │
               └───────────────┘
```

## Manual Deployment Trigger

To manually trigger a deployment:

```powershell
# Trigger deployment via GitHub CLI
gh workflow run ci.yml `
  --repo petro-konopelko/smartcafe-infrastructure `
  -f environment=dev
```

Or use GitHub UI:
1. Go to **Actions** tab
2. Select **Deploy Infrastructure (Main Branch)** workflow
3. Click **Run workflow** button
4. Select environment (dev/staging/prod)
5. Click **Run workflow**

## Deployment Approval

After a push to `main` triggers the deployment workflow:

1. Workflow runs validation jobs
2. Waits for manual approval in the `{environment}-deployment` environment
3. Go to repository → **Actions** tab
4. Find the pending deployment
5. Click **Review deployments** button
6. Select **Approve and deploy**

Only the repository owner can approve deployments.

## Environment Protection Rules

Configure approval requirements:

1. Go to **Settings** → **Environments**
2. Create/edit `{environment}-deployment` environment
3. Add **Required reviewers**:
   - Set to repository owner or specific users
4. (Optional) Add **Wait timer**:
   - Delay deployment by X minutes
5. Ensure **Deployment branches** is set to `main`

## Monitoring and Troubleshooting

### View Workflow Runs

- **GitHub**: Actions tab → Select workflow → View run logs
- **Azure Portal**: Resource Group → Deployments → View logs

### Common Issues

| Issue | Solution |
|-------|----------|
| Authentication fails | Verify AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID are correct |
| Insufficient permissions | Ensure service principal has Contributor role |
| Validation fails | Check bicep files for syntax errors or lint warnings |
| Deployment fails | Check Azure Portal deployment logs for details |
| Resource group not found | Run `az group create` command from setup |

### Debug Logs

Enable debug logging:
```powershell
# Set GitHub Actions debug environment variable
gh secret set ACTIONS_STEP_DEBUG --body "true"
```

## Bicep Validation Details

The validation workflow checks:

1. **Syntax**: `az bicep build` - Compiles to ARM template
2. **Lint**: `az bicep lint` - Checks best practices
3. **Parameters**: JSON validity
4. **Deployment**: Template validation in Azure (dry-run)

## CI/CD Managed Identity Setup

### Overview

The infrastructure now includes automated setup for CI/CD deployments using User-Assigned Managed Identities with federated credentials. This eliminates the need for storing Azure credentials as GitHub secrets.

### How It Works

1. **Bicep Template Creates:**
   - User-Assigned Managed Identity (UAMI) for each app service
   - Federated credential trusting GitHub OIDC for specific repo/environment
   - Website Contributor role assignment to the App Service

2. **GitHub Actions Authenticates:**
   - Uses OIDC token from GitHub
   - Exchanges it for Azure access token via federated credential
   - Deploys to App Service using managed identity

### Module Usage

```bicep
// In main.bicep
module menuAppDeploymentIdentity 'modules/appservice-deployment-identity.bicep' = {
  params: {
    location: location
    managedIdentityName: '${environment}-uami-menu-${location}-${projectName}'
    tags: tags
    githubRepository: 'petro-konopelko/smartcafe-menu'  // Your app repo
    githubEnvironment: environment                       // dev/staging/prod
    appServiceName: appServiceConfigs[0].name
    websiteContributorRoleId: azureRoles.WebsiteContributor
  }
}
```

### Required GitHub Secrets (App Repository)

For each application repository (e.g., `smartcafe-menu`), configure:

```
AZURE_CLIENT_ID              # Managed Identity Client ID (from Bicep output)
AZURE_TENANT_ID              # Azure AD Tenant ID
AZURE_SUBSCRIPTION_ID        # Azure Subscription ID
```

These values are output by the infrastructure deployment and can be found in the deployment outputs.

## File Structure

```
.github/
├── README.md                    # This file
└── workflows/
    ├── bicep-validate.yml       # Reusable validation composite action
    ├── pr.yml                   # Pull request validation workflow
    └── ci.yml                   # Main branch deployment workflow

bicep/
├── modules/
│   ├── rbac/
│   │   ├── keyvault.bicep          # Key Vault RBAC assignments
│   │   ├── storage.bicep           # Storage RBAC assignments
│   │   └── appservice.bicep        # App Service RBAC assignments
│   ├── appservice-deployment-identity.bicep  # Combined UAMI + RBAC for CI/CD
│   ├── app-service.bicep           # App Service resources
│   ├── keyvault.bicep              # Key Vault resources
│   ├── network.bicep               # Virtual Network resources
│   └── postgresql.bicep            # PostgreSQL resources
├── types/
│   └── rbac.bicep                  # RBAC type definitions
└── variables/
    └── azure-roles.json            # Azure role GUID mappings
```

## Next Steps

1. ✅ Configure secrets
2. ✅ Create service principal
3. ✅ Create resource groups
4. ✅ Create pull request to test validation
5. ✅ Merge to main to test deployment
6. ✅ Configure approval rules for production

---

**Need Help?** Check the main [README.md](../README.md) for architecture details.
