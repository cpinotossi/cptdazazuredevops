# Terraform Destroy Instructions

## Issue: Service Connection Deletion Error

When running `terraform destroy`, you may encounter this error:

```
Error: Delete service endpoint error Cannot delete this service connection while 
federated credentials for app <client-id> exist in Entra tenant <tenant-id>. 
Please make sure federated credentials have been removed prior to deleting the 
service connection.
```

## Why This Happens

Azure DevOps service connections cannot be deleted while federated identity credentials still exist in Entra ID. This is a Azure DevOps API limitation that prevents deletion to avoid orphaned credentials.

## Solution 1: Two-Step Destroy (Recommended)

Destroy resources in two stages to ensure proper deletion order:

```powershell
# Step 1: Destroy Azure resources (including federated credentials)
terraform destroy -target=module.azure -auto-approve

# Step 2: Destroy Azure DevOps resources (including service connections)
terraform destroy -auto-approve
```

## Solution 2: Manual Cleanup

If Step 1 fails, manually delete the federated credentials first:

1. **Find the managed identities** (plan and apply):
   ```powershell
   az identity list --resource-group rg-storage-demo-identity-germanywestcentral-001 --query "[].{Name:name, ClientId:clientId}" -o table
   ```

2. **List federated credentials for each identity**:
   ```powershell
   az identity federated-credential list \
     --resource-group rg-storage-demo-identity-germanywestcentral-001 \
     --identity-name <identity-name>
   ```

3. **Delete each federated credential**:
   ```powershell
   az identity federated-credential delete \
     --resource-group rg-storage-demo-identity-germanywestcentral-001 \
     --identity-name <identity-name> \
     --name <credential-name>
   ```

4. **Then run destroy**:
   ```powershell
   terraform destroy -auto-approve
   ```

## Solution 3: Script-Based Cleanup

Use the provided cleanup script:

```powershell
.\scripts\Pre-Destroy-Cleanup.ps1
terraform destroy -auto-approve
```

## Prevention

This is a known limitation of the Azure DevOps API and cannot be fully automated within Terraform due to circular dependencies between modules. The two-step destroy process is the recommended approach.
