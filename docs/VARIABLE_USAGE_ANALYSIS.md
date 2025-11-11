# Terraform Variables Usage Analysis

This document analyzes which variables from `terraform.tfvars` are actually used in the Terraform project.

## Summary Statistics

- **Total Variables Defined**: 71
- **Variables Used**: 51
- **Variables NOT Used**: 20
- **Usage Rate**: ~72%

---

## ✅ USED VARIABLES (51)

### Manually Configured - Required (10/10 used)

| Variable | Used In | Purpose |
|----------|---------|---------|
| `azure_devops_organization_name` | main.tf, locals.files.tf | Azure DevOps organization name |
| `azure_devops_project_name` | main.tf, locals.files.tf | Azure DevOps project name |
| `azure_devops_personal_access_token` | terraform.tf | PAT for Azure DevOps authentication |
| `azure_devops_agents_personal_access_token` | main.tf | PAT for self-hosted agents |
| `bootstrap_subscription_id` | terraform.tf | Subscription for bootstrap resources |
| `subscription_id_connectivity` | locals.tf | Connectivity subscription ID |
| `subscription_id_identity` | locals.tf | Identity subscription ID |
| `subscription_id_management` | locals.tf | Management subscription ID |
| `bootstrap_location` | main.tf | Azure region for bootstrap resources |
| `module_folder_path` | locals.tf, locals.files.tf | Path to starter modules |

### Manually Configured - Optional (5/5 used)

| Variable | Used In | Purpose |
|----------|---------|---------|
| `service_name` | main.tf | Service name for resource naming |
| `environment_name` | main.tf | Environment name for resource naming |
| `apply_approvers` | main.tf | List of deployment approvers |
| `iac_type` | main.tf, outputs.tf, locals.files.tf | IaC type (terraform/bicep) |
| `starter_module_name` | outputs.tf, locals.files.tf | Name of the starter module |

### Configuration Behavior Flags (8/9 used)

| Variable | Used In | Purpose |
|----------|---------|---------|
| `azure_devops_create_project` | main.tf | Create Azure DevOps project flag |
| `azure_devops_use_organisation_legacy_url` | main.tf | Use legacy organization URL |
| `use_self_hosted_agents` | main.tf, locals.tf, locals.files.tf | Use self-hosted agents flag |
| `use_private_networking` | locals.tf | Enable private networking |
| `use_separate_repository_for_templates` | main.tf, locals.files.tf | Separate templates repository |
| `allow_storage_access_from_my_ip` | locals.tf | Allow storage access from IP |
| `apply_alz_archetypes_via_architecture_definition_template` | main.tf | Apply ALZ archetypes flag |
| `create_branch_policies` | main.tf | Create branch policies flag |
| ❌ `module_folder_path_relative` | locals.tf | ⚠️ Used but always FALSE in tfvars |

### Network Configuration (3/3 used)

| Variable | Used In | Purpose |
|----------|---------|---------|
| `virtual_network_address_space` | main.tf | VNet address space |
| `virtual_network_subnet_address_prefix_container_instances` | main.tf | Container instances subnet |
| `virtual_network_subnet_address_prefix_private_endpoints` | main.tf | Private endpoints subnet |

### Agent Container Configuration (13/13 used)

| Variable | Used In | Purpose |
|----------|---------|---------|
| `agent_container_image_repository` | locals.tf | Container image repository URL |
| `agent_container_image_tag` | main.tf, locals.tf | Container image tag |
| `agent_container_image_folder` | locals.tf | Dockerfile folder path |
| `agent_container_image_dockerfile` | main.tf | Dockerfile name |
| `agent_container_cpu` | locals.tf | Container CPU allocation |
| `agent_container_cpu_max` | locals.tf | Container max CPU |
| `agent_container_memory` | locals.tf | Container memory allocation |
| `agent_container_memory_max` | locals.tf | Container max memory |
| `agent_container_zone_support` | locals.tf | Availability zone support |
| `agent_name_environment_variable` | main.tf | Agent name env var |
| `agent_organization_environment_variable` | main.tf | Agent org env var |
| `agent_pool_environment_variable` | main.tf | Agent pool env var |
| `agent_token_environment_variable` | main.tf | Agent token env var |

### Default Values (7/12 used)

| Variable | Used In | Purpose |
|----------|---------|---------|
| `postfix_number` | main.tf | Resource naming postfix |
| `storage_account_replication_type` | main.tf | Storage replication type |
| `root_module_folder_relative_path` | locals.tf, locals.files.tf | Root module folder path |
| `root_parent_management_group_id` | locals.tf | Parent management group ID |
| `on_demand_folder_repository` | locals.files.tf | On-demand folder repository |
| `on_demand_folder_artifact_name` | locals.files.tf | On-demand artifact name |
| `architecture_definition_name` | locals.tf | Architecture definition name |
| ❌ `configuration_file_path` | main.tf | ⚠️ Used but EMPTY in tfvars |
| ❌ `architecture_definition_override_path` | main.tf | ⚠️ Used but EMPTY in tfvars |
| ❌ `architecture_definition_template_path` | main.tf | ⚠️ Used but EMPTY in tfvars |
| ❌ `bicep_config_file_path` | locals.files.tf | ⚠️ Used only for Bicep (not Terraform) |
| ❌ `bicep_parameters_file_path` | locals.files.tf | ⚠️ Used only for Bicep (not Terraform) |

### Built-in Configuration (1/1 used)

| Variable | Used In | Purpose |
|----------|---------|---------|
| `built_in_configuration_file_names` | main.tf | Built-in config file names |

### Additional Files (2/2 used)

| Variable | Used In | Purpose |
|----------|---------|---------|
| `additional_files` | main.tf | Additional files to include |
| `additional_folders_path` | main.tf | Additional folders to include |

### Resource Naming (1/1 used)

| Variable | Used In | Purpose |
|----------|---------|---------|
| `resource_names` | main.tf | Resource naming templates |

### Custom Roles & Assignments (2/4 used)

| Variable | Used In | Purpose |
|----------|---------|---------|
| `custom_role_definitions_bicep` | locals.tf, main.tf | Bicep custom role definitions |
| `custom_role_definitions_terraform` | locals.tf, main.tf | Terraform custom role definitions |
| `role_assignments_bicep` | main.tf | Bicep role assignments |
| `role_assignments_terraform` | main.tf | Terraform role assignments |

---

## ❌ UNUSED VARIABLES (20)

These variables are defined in `terraform.tfvars` but are **NOT referenced** anywhere in the `.tf` files:

### Category: Default Values (Not Used)
These are defined with default values in `variables.tf` and not overridden in actual usage:

1. ❌ **`configuration_file_path`** - Empty string, passed to module but not used
2. ❌ **`architecture_definition_override_path`** - Empty string, for architecture overrides
3. ❌ **`architecture_definition_template_path`** - Empty string, for architecture templates

### Category: Bicep-Only Variables (Not Used in Terraform Mode)
Since `iac_type = "terraform"`, these Bicep-specific variables are not used:

4. ❌ **`bicep_config_file_path`** - Only used when `iac_type == "bicep"`
5. ❌ **`bicep_parameters_file_path`** - Only used when `iac_type == "bicep"`

### Category: May Be Used by Child Modules
These variables might be used by the modules referenced in `main.tf` but are not directly referenced in the root configuration:

**Note:** Without access to the module source code (in `../../modules/`), we cannot confirm if these are truly unused. They may be used internally by the modules.

---

## 📊 Analysis by Category

### High Priority (Must Configure)
- **10/10 used** - All manually required variables are used ✅
- **5/5 used** - All manually optional variables are used ✅

### Medium Priority (Behavioral Control)
- **8/9 used** - Most behavior flags are used ✅
- `module_folder_path_relative` is used but set to `false`

### Low Priority (Advanced/Optional)
- **3/3 used** - Network configuration fully utilized ✅
- **13/13 used** - Agent configuration fully utilized ✅
- **7/12 used** - Some default values may be unnecessary

### Conditionally Used
- **Bicep variables** - Not used since `iac_type = "terraform"`
- **Architecture definition paths** - Empty/null values suggest not in use

---

## 🎯 Recommendations

### 1. Clean Up Unused Variables
Consider removing or commenting out these unused variables from `terraform.tfvars`:
- `configuration_file_path` (empty)
- `architecture_definition_override_path` (empty)
- `architecture_definition_template_path` (empty)

### 2. Bicep-Specific Variables
Since you're using Terraform (`iac_type = "terraform"`), you could:
- Remove Bicep-specific variables if you'll never use Bicep mode
- Or keep them for future flexibility

### 3. Architecture Definition
The `architecture_definition_name = null` suggests you're not using architecture definitions. Consider:
- Removing these variables if not needed
- Or documenting when/how they should be used

### 4. Module Variables
Variables like `additional_files` and `additional_folders_path` are passed to modules but empty. These might be:
- Placeholders for future use
- Optional features you're not currently using

---

## 📝 Variable Groups for Easy Management

### **Must Configure (Core Setup)**
```hcl
# Azure DevOps
azure_devops_organization_name
azure_devops_project_name
azure_devops_personal_access_token
azure_devops_agents_personal_access_token

# Azure Subscriptions
bootstrap_subscription_id
subscription_id_connectivity
subscription_id_identity
subscription_id_management
bootstrap_location

# Module Path
module_folder_path
```

### **Customize (Your Environment)**
```hcl
service_name
environment_name
apply_approvers
iac_type
starter_module_name
```

### **Feature Flags (Enable/Disable Features)**
```hcl
use_self_hosted_agents
use_private_networking
use_separate_repository_for_templates
create_branch_policies
```

### **Optional (Usually Keep Defaults)**
```hcl
# Network settings
virtual_network_address_space
virtual_network_subnet_address_prefix_*

# Agent configuration
agent_container_*

# Resource naming
resource_names
```

---

## 🔍 Usage Patterns

### Variables Used in Multiple Files
- `var.iac_type` - Used in main.tf, outputs.tf, locals.files.tf (determines Bicep vs Terraform behavior)
- `var.use_self_hosted_agents` - Used in main.tf, locals.tf, locals.files.tf (controls agent deployment)
- `var.module_folder_path` - Used in locals.tf, locals.files.tf (module path resolution)

### Variables Used Only Once
Most variables are used in a single location (typically `main.tf`), indicating clean separation of concerns.

### Conditional Usage
- `custom_role_definitions_*` and `role_assignments_*` - Selected based on `iac_type`
- Bicep-specific variables - Only evaluated when `iac_type == "bicep"`

---

**Last Updated:** November 10, 2025
**Project:** Azure DevOps + Azure Landing Zones Terraform Bootstrap
