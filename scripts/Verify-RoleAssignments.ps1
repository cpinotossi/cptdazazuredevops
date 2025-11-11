<#
.SYNOPSIS
    Verifies that managed identities have been assigned the expected custom roles.

.DESCRIPTION
    This script checks if the managed identities (plan and apply) have the correct
    custom role assignments on the target subscription as defined in terraform.tfvars.

.PARAMETER SubscriptionId
    The target subscription ID to check role assignments on.

.PARAMETER ResourceGroupIdentity
    The resource group name where the managed identities are located.

.PARAMETER IdentityNamePlan
    The name of the managed identity used for planning.

.PARAMETER IdentityNameApply
    The name of the managed identity used for applying.

.EXAMPLE
    .\Verify-RoleAssignments.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetSubscriptionId = "4b353dc5-a216-485d-8f77-a0943546b42c",
    
    [Parameter(Mandatory = $false)]
    [string]$BootstrapSubscriptionId = "b629af82-f93c-4bc8-9bb2-8e299758bbe7",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupIdentity = "rg-storage-demo-identity-germanywestcentral-001",
    
    [Parameter(Mandatory = $false)]
    [string]$IdentityNamePlan = "id-storage-demo-germanywestcentral-plan-001",
    
    [Parameter(Mandatory = $false)]
    [string]$IdentityNameApply = "id-storage-demo-germanywestcentral-apply-001"
)

$ErrorActionPreference = "Stop"

# Colors for output
$ColorSuccess = "Green"
$ColorError = "Red"
$ColorWarning = "Yellow"
$ColorInfo = "Cyan"

Write-Host "`n========================================" -ForegroundColor $ColorInfo
Write-Host "Role Assignment Verification Script" -ForegroundColor $ColorInfo
Write-Host "========================================`n" -ForegroundColor $ColorInfo

# Check if logged in to Azure
Write-Host "Checking Azure CLI authentication..." -ForegroundColor $ColorInfo
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Not logged in to Azure CLI. Please run 'az login'" -ForegroundColor $ColorError
    exit 1
}
Write-Host "Logged in as: $($account.user.name)" -ForegroundColor $ColorSuccess

# Set subscription context to bootstrap (where identities are located)
Write-Host "`nSetting subscription context to bootstrap subscription..." -ForegroundColor $ColorInfo
az account set --subscription $BootstrapSubscriptionId 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to set bootstrap subscription" -ForegroundColor $ColorError
    exit 1
}
Write-Host "Bootstrap subscription set to: $BootstrapSubscriptionId" -ForegroundColor $ColorSuccess

# Function to get managed identity details
function Get-ManagedIdentityDetails {
    param(
        [string]$ResourceGroup,
        [string]$IdentityName
    )
    
    Write-Host "`nRetrieving managed identity: $IdentityName..." -ForegroundColor $ColorInfo
    $identity = az identity show `
        --resource-group $ResourceGroup `
        --name $IdentityName `
        2>$null | ConvertFrom-Json
    
    if ($identity) {
        Write-Host "Found managed identity" -ForegroundColor $ColorSuccess
        Write-Host "  - Name: $($identity.name)" -ForegroundColor Gray
        Write-Host "  - Principal ID: $($identity.principalId)" -ForegroundColor Gray
        Write-Host "  - Client ID: $($identity.clientId)" -ForegroundColor Gray
        return $identity
    } else {
        Write-Host "Managed identity not found" -ForegroundColor $ColorError
        return $null
    }
}

# Function to get custom role definition
function Get-CustomRoleDefinition {
    param(
        [string]$RoleNamePattern,
        [string]$SubscriptionId
    )
    
    Write-Host "`nSearching for custom role: $RoleNamePattern..." -ForegroundColor $ColorInfo
    $roles = az role definition list `
        --subscription $SubscriptionId `
        --custom-role-only true `
        2>$null | ConvertFrom-Json
    
    $matchingRole = $roles | Where-Object { $_.roleName -like "*$RoleNamePattern*" }
    
    if ($matchingRole) {
        Write-Host "Found custom role: $($matchingRole.roleName)" -ForegroundColor $ColorSuccess
        Write-Host "  - Role ID: $($matchingRole.name)" -ForegroundColor Gray
        Write-Host "  - Description: $($matchingRole.description)" -ForegroundColor Gray
        return $matchingRole
    } else {
        Write-Host "Custom role not found" -ForegroundColor $ColorError
        return $null
    }
}

# Function to get role assignments for a principal
function Get-RoleAssignmentsForPrincipal {
    param(
        [string]$PrincipalId,
        [string]$Scope
    )
    
    Write-Host "`nChecking role assignments at subscription scope..." -ForegroundColor $ColorInfo
    $assignments = az role assignment list `
        --assignee $PrincipalId `
        --scope $Scope `
        2>$null | ConvertFrom-Json
    
    if ($assignments -and $assignments.Count -gt 0) {
        Write-Host "Found $($assignments.Count) role assignment(s)" -ForegroundColor $ColorSuccess
        foreach ($assignment in $assignments) {
            Write-Host "  - Role: $($assignment.roleDefinitionName)" -ForegroundColor Gray
            Write-Host "    Role ID: $($assignment.roleDefinitionId)" -ForegroundColor Gray
            Write-Host "    Scope: $($assignment.scope)" -ForegroundColor Gray
        }
        return $assignments
    } else {
        Write-Host "No role assignments found" -ForegroundColor $ColorWarning
        return @()
    }
}

# Function to verify role assignment
function Test-RoleAssignment {
    param(
        [object]$Identity,
        [object]$ExpectedRole,
        [string]$Scope,
        [string]$Description
    )
    
    Write-Host "`n----------------------------------------" -ForegroundColor $ColorInfo
    Write-Host "Verifying: $Description" -ForegroundColor $ColorInfo
    Write-Host "----------------------------------------" -ForegroundColor $ColorInfo
    
    if (-not $Identity) {
        Write-Host "FAILED: Managed identity not found" -ForegroundColor $ColorError
        return $false
    }
    
    if (-not $ExpectedRole) {
        Write-Host "FAILED: Expected custom role not found" -ForegroundColor $ColorError
        return $false
    }
    
    $assignments = Get-RoleAssignmentsForPrincipal -PrincipalId $Identity.principalId -Scope $Scope
    
    $hasExpectedRole = $false
    foreach ($assignment in $assignments) {
        if ($assignment.roleDefinitionId -eq $ExpectedRole.id) {
            $hasExpectedRole = $true
            break
        }
    }
    
    if ($hasExpectedRole) {
        Write-Host "`nSUCCESS: Role assignment verified" -ForegroundColor $ColorSuccess
        Write-Host "  Identity: $($Identity.name)" -ForegroundColor Gray
        Write-Host "  Role: $($ExpectedRole.roleName)" -ForegroundColor Gray
        Write-Host "  Scope: $Scope" -ForegroundColor Gray
        return $true
    } else {
        Write-Host "`nFAILED: Expected role not assigned" -ForegroundColor $ColorError
        Write-Host "  Identity: $($Identity.name)" -ForegroundColor Gray
        Write-Host "  Expected Role: $($ExpectedRole.roleName)" -ForegroundColor Gray
        Write-Host "  Scope: $Scope" -ForegroundColor Gray
        return $false
    }
}

# Main verification logic
Write-Host "`n========================================" -ForegroundColor $ColorInfo
Write-Host "Starting Verification Process" -ForegroundColor $ColorInfo
Write-Host "========================================" -ForegroundColor $ColorInfo

$targetSubscriptionScope = "/subscriptions/$TargetSubscriptionId"

# Get managed identities (from bootstrap subscription)
$identityPlan = Get-ManagedIdentityDetails -ResourceGroup $ResourceGroupIdentity -IdentityName $IdentityNamePlan
$identityApply = Get-ManagedIdentityDetails -ResourceGroup $ResourceGroupIdentity -IdentityName $IdentityNameApply

# Get custom roles (from target subscription)
Write-Host "`nSwitching to target subscription for role lookups..." -ForegroundColor $ColorInfo
az account set --subscription $TargetSubscriptionId 2>$null
Write-Host "Target subscription set to: $TargetSubscriptionId" -ForegroundColor $ColorSuccess

$rolePlan = Get-CustomRoleDefinition -RoleNamePattern "Simple Storage VM Reader" -SubscriptionId $TargetSubscriptionId
$roleApply = Get-CustomRoleDefinition -RoleNamePattern "Simple Storage VM Contributor" -SubscriptionId $TargetSubscriptionId

# Verify assignments (on target subscription scope)
$results = @()
$results += Test-RoleAssignment `
    -Identity $identityPlan `
    -ExpectedRole $rolePlan `
    -Scope $targetSubscriptionScope `
    -Description "Plan Identity - Reader Role"

$results += Test-RoleAssignment `
    -Identity $identityApply `
    -ExpectedRole $roleApply `
    -Scope $targetSubscriptionScope `
    -Description "Apply Identity - Contributor Role"

# Summary
Write-Host "`n========================================" -ForegroundColor $ColorInfo
Write-Host "Verification Summary" -ForegroundColor $ColorInfo
Write-Host "========================================" -ForegroundColor $ColorInfo

$successCount = ($results | Where-Object { $_ -eq $true }).Count
$totalCount = $results.Count

Write-Host "`nTotal Checks: $totalCount" -ForegroundColor $ColorInfo
Write-Host "Passed: $successCount" -ForegroundColor $(if ($successCount -eq $totalCount) { $ColorSuccess } else { $ColorWarning })
Write-Host "Failed: $($totalCount - $successCount)" -ForegroundColor $(if ($successCount -eq $totalCount) { $ColorSuccess } else { $ColorError })

if ($successCount -eq $totalCount) {
    Write-Host "`nAll role assignments verified successfully!" -ForegroundColor $ColorSuccess
    exit 0
} else {
    Write-Host "`nSome role assignments are missing or incorrect!" -ForegroundColor $ColorError
    exit 1
}
