# Scripts Documentation

## Verify-RoleAssignments.ps1

### Purpose
Verifies that managed identities have been assigned the expected custom roles in Azure, as defined in the `terraform.tfvars` configuration.

### Prerequisites
- Azure CLI installed and authenticated (`az login`)
- Access to the target subscription
- Resources must be deployed (run `terraform apply` first)

### Usage

**Basic usage** (uses default values from terraform.tfvars):
```powershell
.\scripts\Verify-RoleAssignments.ps1
```

**Custom parameters**:
```powershell
.\scripts\Verify-RoleAssignments.ps1 `
    -SubscriptionId "4b353dc5-a216-485d-8f77-a0943546b42c" `
    -ResourceGroupIdentity "rg-storage-demo-identity-germanywestcentral-001" `
    -IdentityNamePlan "id-storage-demo-germanywestcentral-plan-001" `
    -IdentityNameApply "id-storage-demo-germanywestcentral-apply-001"
```

### What it checks
1. **Plan Identity** - Verifies the managed identity for planning has the "Simple Storage VM Reader" role
2. **Apply Identity** - Verifies the managed identity for applying has the "Simple Storage VM Contributor" role

### Expected output
When successful:
```
========================================
Role Assignment Verification Script
========================================

Checking Azure CLI authentication...
Logged in as: user@domain.com

Setting subscription context...
Subscription set to: 4b353dc5-a216-485d-8f77-a0943546b42c

...

========================================
Verification Summary
========================================

Total Checks: 2
Passed: 2
Failed: 0

All role assignments verified successfully!
```

### Exit codes
- `0` - All verifications passed
- `1` - One or more verifications failed

### Note
If you've run `terraform destroy`, this script will fail because the resources no longer exist. Run `terraform apply` first to deploy the infrastructure before verifying role assignments.
