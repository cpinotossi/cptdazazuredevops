# Quick Start Guide - Simple Storage VM Deployment

## Prerequisites Checklist

- [ ] Azure subscription with appropriate permissions
- [ ] Azure DevOps organization access
- [ ] Azure DevOps Personal Access Tokens (already configured in terraform.tfvars)
- [ ] SSH key pair for VM access
- [ ] Terraform >= 1.9 installed
- [ ] PowerShell or Bash terminal

## Step 1: Configure the Starter Module

```powershell
cd C:\Users\chpinoto\workspace\vbd\bvg\datahub\storage
cp terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
```

**Required Changes in `storage/terraform.tfvars`:**

1. **storage_account_name**: Must be globally unique, 3-24 lowercase alphanumeric characters
   ```hcl
   storage_account_name = "stgsimpledemogwc001"  # Change this!
   ```

2. **admin_password**: Secure password for VM access
   ```hcl
   admin_password = "YourSecureP@ssw0rd123!"  # Change this!
   ```
   Must meet Azure requirements: 12-72 characters with uppercase, lowercase, number, and special character

3. **Optional**: Adjust other values (resource names, network ranges, VM size)

## Step 2: Deploy the Bootstrap Infrastructure

```powershell
cd C:\Users\chpinoto\workspace\vbd\bvg\datahub\azuredevops

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy (creates Azure DevOps project, pipelines, managed identities, etc.)
terraform apply
```

**What gets deployed:**
- Azure DevOps project `alz1`
- Repository `storage-demo` with your starter module code
- CI/CD pipelines:
  - "01 Simple Storage VM Continuous Integration"
  - "02 Simple Storage VM Continuous Delivery"
- Managed identities for plan and apply operations with RBAC
- Self-hosted agents in Azure Container Instances
- Terraform state storage
- Private networking infrastructure

## Step 3: Trigger the Deployment Pipeline

After the bootstrap completes:

1. **Navigate to Azure DevOps:**
   ```
   https://dev.azure.com/cptdazlz/alz1
   ```

2. **Go to Pipelines** and find:
   - "01 Simple Storage VM Continuous Integration" (CI)
   - "02 Simple Storage VM Continuous Delivery" (CD)

3. **Run the CI pipeline** to validate the code

4. **Run the CD pipeline** to deploy infrastructure:
   - Uses managed identity authentication
   - Deploys to subscription: `1f7a05b9-efb0-4c6f-9ead-a57fd33b4b31`
   - Creates resource group and all resources

## Step 4: Verify Deployment

### Check in Azure Portal

Navigate to resource group `rg-storage-demo` (or your configured name):
- ✅ Storage account
- ✅ Virtual network with 2 subnets
- ✅ Ubuntu VM (no public IP - private access only)
- ✅ Network interface
- ✅ Private endpoint
- ✅ Private DNS zone

### Access the VM

The VM has no public IP and can be accessed via:
- **Azure Bastion** (deploy separately in the VNet)
- **VPN Gateway** connection
- **Azure Serial Console** (emergency access)
- **Just-in-Time (JIT) VM Access** via Azure Security Center

#### Using Azure Portal Serial Console

1. Navigate to Azure Portal → VM → Serial Console
2. Login with username: `azureuser` and your configured password

### Test VM Access to Storage

Once connected to the VM:

```bash
# Install Azure CLI on VM
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login with managed identity
az login --identity

# Verify identity has access
az storage container list \
  --account-name <your-storage-account-name> \
  --auth-mode login

# Should successfully list containers using managed identity!
```

## Step 5: Test Storage Access from Your Machine

Your public IP is automatically allowed in the storage firewall:

```powershell
# Using Azure CLI
az storage container list \
  --account-name <your-storage-account-name> \
  --auth-mode login

# Or using Azure Portal - you should be able to browse blobs
```

## Troubleshooting

### Issue: Storage account name already exists

**Solution:** Change `storage_account_name` to something globally unique in `storage/terraform.tfvars`

### Issue: Password doesn't meet requirements

**Solution:** Use a password with 12-72 characters including uppercase, lowercase, number, and special character

### Issue: Cannot access VM

**Solution:** VM has no public IP. Use Azure Bastion, VPN Gateway, or Serial Console for access
**Solution:** Your public IP may have changed. Redeploy or add your new IP to storage firewall rules

### Issue: VM cannot access storage
**Solution:** Check:
- VM managed identity is assigned
- RBAC role assignment exists (Storage Blob Data Reader)
- Network rules allow VM subnet

### Issue: Pipeline fails with permission error
**Solution:** 
- Verify managed identities were created by bootstrap
- Check RBAC role assignments in Azure Portal
- Ensure target subscription ID is correct

## Architecture Overview

```
Bootstrap Subscription (aaf0e6dd-...)
  └── Resource Groups
      ├── rg-storage-demo-agents-germanywestcentral-1
      │   └── Container instances (self-hosted agents)
      ├── rg-storage-demo-identity-germanywestcentral-1
      │   ├── Managed Identity (plan)
      │   └── Managed Identity (apply)
      ├── rg-storage-demo-network-germanywestcentral-1
      │   └── VNet for agents
      └── rg-storage-demo-state-germanywestcentral-1
          └── Storage account (Terraform state)

Target Subscription (1f7a05b9-...)
  └── Resource Group: rg-storage-demo
      ├── Storage Account (private endpoint enabled)
      ├── Virtual Network
      │   ├── Subnet: subnet-vm
      │   └── Subnet: subnet-pe
      ├── Ubuntu VM (with managed identity)
      ├── Network Interface
      ├── Private Endpoint (for storage)
      └── Private DNS Zone
```

## Next Steps

1. ✅ Deploy bootstrap infrastructure
2. ✅ Trigger CI/CD pipelines in Azure DevOps
3. ✅ Verify resources in Azure Portal
4. ✅ Test VM access to storage using managed identity
5. 🎯 Customize the module for your specific needs
6. 🎯 Add more resources (e.g., NSG rules, public IP for VM, etc.)
7. 🎯 Configure monitoring and alerts

## Important Notes

- **State Management**: Terraform state is stored in Azure Storage Account created by bootstrap
- **Authentication**: Pipelines use federated credentials with managed identities (no secrets!)
- **RBAC**: Custom roles are scoped to subscription level only
- **Networking**: VM uses service endpoint; private endpoint provides internal access path
- **Security**: Storage account denies public access except for your IP and VM subnet

## Clean Up

To remove all resources:

```powershell
# Remove deployed infrastructure (from Azure DevOps pipeline)
# Or manually via Terraform in the deployed repository

# Remove bootstrap infrastructure
cd C:\Users\chpinoto\workspace\vbd\bvg\datahub\azuredevops
terraform destroy
```

**Warning:** This will delete all Azure DevOps resources, pipelines, and Azure infrastructure!
