# SmartCafe Infrastructure as Code

Azure infrastructure for SmartCafe application using Bicep templates with GitHub Actions CI/CD.

## 🏗️ Architecture Overview

Complete Azure environment for SmartCafe:

```
┌──────────────────────────────────────────────────────────────┐
│                 Azure Subscription                            │
│  ┌────────────────────────────────────────────────────────┐  │
│  │    Resource Group: dev-rg-northeurope-smartcafe │
│  │                                                         │  │
│  │  ┌──────────────────────────────────────────────────┐   │  │
│  │  │ VNet (10.0.0.0/16)                              │   │  │
│  │  │                                                   │   │  │
│  │  │ DB Subnet (10.0.1.0/26)                         │   │  │
│  │  │ └─ PostgreSQL (Burstable B1ms, Private)         │   │  │
│  │  │                                                   │   │  │
│  │  │ App Subnet (10.0.2.0/24)                        │   │  │
│  │  │ └─ App Service (Basic B1, .NET 10)             │   │  │
│  │  │    └─ Managed Identity                          │   │  │
│  │  └──────────────────────────────────────────────────┘   │  │
│  │                                                         │  │
│  │  Key Vault (Secrets, RBAC)                            │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
smartcafe-infrastructure/
├── bicep/                                # All Bicep templates
│   ├── main.bicep                       # Main orchestrator
│   ├── types/
│   │   ├── network.bicep               # Network type definitions
│   │   ├── tags.bicep                  # Tag type definitions
│   │   └── environment.bicep           # Environment type definitions
│   ├── variables/
│   │   └── shared-variables.json       # Shared variables
│   ├── modules/
│   │   ├── network.bicep               # VNet, Subnets, NSGs
│   │   ├── keyvault.bicep              # Key Vault
│   │   ├── keyvault-rbac.bicep         # RBAC assignments
│   │   ├── postgresql.bicep            # PostgreSQL
│   │   └── app-service.bicep           # App Service
│   └── parameters/
│       ├── dev.bicepparam              # Dev parameters (Bicep)
│       ├── staging.bicepparam          # Staging parameters (Bicep)
│       ├── prod.bicepparam             # Production parameters (Bicep)
│       └── dev.parameters.json         # Dev parameters (Legacy)
│
├── .github/workflows/
│   ├── bicep-validate.yml              # Reusable validation
│   ├── pr.yml                          # PR validation
│   └── ci.yml                          # Deployment + approval
│
└── README.md                            # This file
```

## 🚀 Quick Start

### 1. Prerequisites

- Azure subscription
- Azure CLI installed
- GitHub repository access
- Service Principal with Contributor role

### 2. Configure GitHub Secrets

Add these secrets to your repository (Settings → Secrets):

```
AZURE_CLIENT_ID              # Service Principal Client ID
AZURE_TENANT_ID              # Azure AD Tenant ID
AZURE_SUBSCRIPTION_ID        # Azure Subscription ID
POSTGRES_ADMIN_LOGIN         # DB admin login (e.g., smartcafeadmin)
POSTGRES_ADMIN_PASSWORD      # DB admin password (strong!)
```

### 3. Deploy

Simply push to `main` branch:

1. **PR Validation** - Automatic validation on pull request
2. **Manual Approval** - Repository owner approves deployment
3. **Deployment** - Infrastructure deployed to Azure

## 🔧 Deployment Workflows

### Pull Request Validation (Automatic)

Triggered on PR to `main`:
- ✅ Validates Bicep syntax
- ✅ Lints all Bicep files
- ✅ Validates parameter files
- ✅ Validates ARM template
- 💬 Posts results as PR comment

### Main Branch Deployment (Manual Approval Required)

Triggered on push to `main`:
1. **Validate** - Same as PR validation
2. **Await Approval** - Waits for repository owner approval
3. **Deploy** - Deploys infrastructure
4. **Notify** - Reports deployment results

Approve deployment in GitHub Actions tab.

## 📊 Resource Naming

Convention: `{env}-smartcafe-{region}-{resource}`

| Resource | Name Example | Cost |
|----------|------|------|
| Resource Group | `dev-resourcegroup-northeurope-smartcafe` | $0 |
| App Service Plan | `dev-asp-northeurope-smartcafe` | ~$13/month (B1) |
| App Service | `dev-app-northeurope-smartcafe` | Included |
| PostgreSQL | `dev-postgres-northeurope-smartcafe` | ~$12-15/month |
| Key Vault | `dev-kv-northeurope-sc` | $0.03/month |
| VNet & NSGs | `dev-vnet-northeurope-smartcafe` | $0 |
| **Total** | | **~$25-28/month** |

## 🔐 Security Features

✅ **Managed Identity** - No credentials to manage  
✅ **Private Database** - Only accessible from app subnet  
✅ **RBAC** - Role-based access control via Key Vault  
✅ **HTTPS Only** - Enforced on App Service  
✅ **Network Segmentation** - NSGs with least-privilege rules  
✅ **Azure AD Auth** - Enabled for PostgreSQL  
✅ **Soft-Delete** - Enabled on Key Vault  
✅ **Environment Config** - Separate settings per environment  

## 📝 Environment Configuration

Different settings per environment (dev/staging/prod):

```json
{
  "dev": {
    "environmentTag": "development",
    "environmentDisplayName": "Development",
    "aspnetcoreEnvironment": "Development"
  },
  "staging": {
    "environmentTag": "staging",
    "environmentDisplayName": "Staging",
    "aspnetcoreEnvironment": "Staging"
  },
  "prod": {
    "environmentTag": "production",
    "environmentDisplayName": "Production",
    "aspnetcoreEnvironment": "Production"
  }
}
```

- **environmentTag**: Azure resource tag value (e.g., "development")
- **aspnetcoreEnvironment**: ASP.NET Core environment setting
- **environmentDisplayName**: Human-readable environment name

## 🔑 Parameters vs Variables

**Parameters** - Input values
- `environment` - dev/staging/prod
- `postgresAdminPassword` - From GitHub secrets
- `appServicePlanSku` - From parameters file

**Variables** - Computed values
- `resourceNames` - Naming convention
- `tags` - Default + custom tags
- `environmentConfig` - Per-environment settings

## 💰 Cost Optimization

### Save Money

1. **Stop PostgreSQL** when not in use
   ```powershell
   az postgres flexible-server stop -g dev-resourcegroup-northeurope-smartcafe -n dev-postgres-northeurope-smartcafe
   ```

2. **Use Basic B1** tier for dev (~$13/month)
3. **Minimal backup** retention (7 days)

### Upgrade for Production

For production workloads:
- Upgrade App Service to B1+ (needs VNet integration)
- Enable high availability for PostgreSQL
- Add Application Insights for monitoring
- Add Log Analytics for centralized logging

## 🐛 Troubleshooting

### Validation Fails

Check GitHub Actions logs:
1. Go to Actions tab
2. Find workflow run
3. Click "Validate Templates" job
4. Review error messages

Common issues:
- Syntax errors in `.bicep` files
- Invalid JSON in parameter files
- Missing required parameters

### Deployment Fails

Check Azure Portal:
1. Go to Resource Group
2. Deployments section
3. Click failed deployment
4. View error details

Common issues:
- Resource name already exists
- Insufficient quota
- Missing permissions

### Approval Not Working

Ensure:
- Using federated identity (not client secret)
- Secret `AZURE_CLIENT_ID` configured
- Repository owner has permission
- Deployment environment exists in repository settings

## 📚 Documentation

- **[.github/README.md](.github/README.md)** - GitHub Actions setup
- **[bicep/main.bicep](bicep/main.bicep)** - Main template comments
- **[bicep/modules/](bicep/modules/)** - Module documentation

## 🔄 Workflow Examples

### Manual Deployment Trigger

```powershell
# Using GitHub CLI
gh workflow run ci.yml \
  --repo petro-konopelko/smartcafe-infrastructure \
  -f environment=dev
```

### View Deployment Status

```powershell
# Get latest deployment
az deployment group list \
  --resource-group dev-resourcegroup-northeurope-smartcafe \
  --query "[0]" \
  --output table
```

### Stop PostgreSQL (Save Money)

```powershell
az postgres flexible-server stop \
  --resource-group dev-resourcegroup-northeurope-smartcafe \
  --name dev-postgres-northeurope-smartcafe
```

## 🎯 Next Steps

1. ✅ Configure GitHub secrets (see .github/README.md)
2. ✅ Create pull request to test validation
3. ✅ Merge to main to trigger deployment
4. ✅ Approve deployment in GitHub Actions
5. ✅ Deploy your application code to App Service
6. ✅ Run database migrations
7. ✅ Test your application

## 📊 Monitoring

After deployment, monitor:

- **App Service**: Azure Portal → App Service → Overview
- **PostgreSQL**: Azure Portal → Database → Overview
- **Key Vault**: Azure Portal → Key Vault → Overview
- **Deployment Logs**: GitHub Actions → Deploy workflow

## 🚨 Important Notes

### Free Tier Limitations

⚠️ **VNet Integration requires Basic B1 or higher**
- Free tier (F1) cannot use VNet integration
- Current configuration uses B1 tier (~$13/month)

### PostgreSQL Costs

⚠️ **No free tier available** for PostgreSQL
- Minimum: ~$12-15/month for Burstable B1ms
- **Can stop server when not in use** to reduce costs

### Parameter Security

🔐 **Never commit sensitive parameters**
- Use GitHub secrets for passwords
- Parameter files excluded from git
- Environment variables injected at deployment time

## 📄 License

See LICENSE file

## 🤝 Contributing

This is an infrastructure repository for SmartCafe. For questions or issues, contact the repository owner.

---

**Version**: 2.0 - Refactored with GitHub Actions CI/CD  
**Last Updated**: January 2026  
**Status**: Production Ready
