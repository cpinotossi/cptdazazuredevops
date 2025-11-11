# Azure DevOps Module - Detailed Explanation

This document explains how each Terraform file in the `modules/azure_devops` folder relates to variables defined in `terraform.tfvars` and orchestrates the Azure DevOps infrastructure.

## Table of Contents

- [Overview](#overview)
- [Variable Flow](#variable-flow)
- [Module Files Explained](#module-files-explained)
  - [project.tf](#projecttf)
  - [agent_pool.tf](#agent_pooltf)
  - [environment.tf](#environmenttf)
  - [service_connections.tf](#service_connectionstf)
  - [repository_module.tf](#repository_moduletf)
  - [repository_templates.tf](#repository_templatestf)
  - [variable_group.tf](#variable_grouptf)
  - [groups.tf](#groupstf)
  - [pipeline.tf](#pipelinetf)
  - [locals.tf](#localstf)
  - [locals_pipelines.tf](#locals_pipelinestf)
- [Complete Configuration Flow](#complete-configuration-flow)

---

## Overview

The `azure_devops` module creates the entire Azure DevOps infrastructure including:
- Project creation/reference
- Git repositories (main and templates)
- Service connections with OIDC authentication
- CI/CD pipelines
- Environments with approval controls
- Self-hosted agent pools
- Variable groups for backend configuration
- Branch policies and security controls

All resources are configured through variables passed from `terraform.tfvars` via `main.tf` and transformed through local values.

---

## Variable Flow

Variables flow through the system in this pattern:

```
terraform.tfvars
    ↓
variables.tf (variable declarations)
    ↓
locals.tf / locals.pipelines.tf / locals.files.tf (transformations)
    ↓
main.tf (module.azure_devops call)
    ↓
modules/azure_devops/*.tf (resource creation)
```

---

## Module Files Explained

### project.tf

**Purpose**: Creates or references the Azure DevOps project that will contain all resources.

**Relevant terraform.tfvars Configuration**:

```hcl
azure_devops_project_name = "storagetest"
azure_devops_create_project = true
```
**Configuration Flow Diagram**:

![image project details](media/image.png)


**How it Works**:

```terraform
resource "azuredevops_project" "alz" {
  count = var.create_project ? 1 : 0
  name  = var.project_name
}

data "azuredevops_project" "alz" {
  count = var.create_project ? 0 : 1
  name  = var.project_name
}

locals {
  project_id = var.create_project ? azuredevops_project.alz[0].id : data.azuredevops_project.alz[0].id
}
```

**Explanation**:
- If `azure_devops_create_project = true`, creates a new project named `"storagetest"`
- If `false`, looks up an existing project with that name
- The `local.project_id` is used throughout the module to reference the project
- This conditional approach allows the module to work with both new and existing projects

**Variable Mapping**:
- `var.create_project` ← `azure_devops_create_project`
- `var.project_name` ← `azure_devops_project_name`

---

### agent_pool.tf

**Purpose**: Creates a self-hosted agent pool for running pipelines on custom infrastructure.

**Relevant terraform.tfvars Configuration**:

```hcl
use_self_hosted_agents = true

resource_names = {
  version_control_system_agent_pool = "{{service_name}}-{{environment_name}}"
  # Resolves to: "storage-d1"
}

service_name = "storage"
environment_name = "d1"
```

![image agent pool details](media/image%20copy.png)

**How it Works**:

```terraform
resource "azuredevops_agent_pool" "alz" {
  count          = var.use_self_hosted_agents ? 1 : 0
  name           = var.agent_pool_name
  auto_provision = false
  auto_update    = true
}

resource "azuredevops_agent_queue" "alz" {
  count         = var.use_self_hosted_agents ? 1 : 0
  project_id    = local.project_id
  agent_pool_id = azuredevops_agent_pool.alz[0].id
}
```

**Explanation**:
- Only created when `use_self_hosted_agents = true`
- Creates an agent pool named `"storage-d1"`
- `auto_provision = false` means agents must be manually registered
- `auto_update = true` keeps agent software current
- The agent queue connects the pool to the specific project
- Self-hosted agents run as Azure Container Instances (configured in the `azure` module)

**Variable Mapping**:
- `var.use_self_hosted_agents` ← `use_self_hosted_agents`
- `var.agent_pool_name` ← resolved from `resource_names.version_control_system_agent_pool`

---

### environment.tf

**Purpose**: Creates Azure DevOps environments used for deployment approvals and tracking.

**Relevant terraform.tfvars Configuration**:

```hcl
resource_names = {
  version_control_system_environment_plan = "{{service_name}}-{{environment_name}}-plan"
  version_control_system_environment_apply = "{{service_name}}-{{environment_name}}-apply"
  # Resolve to: "storage-d1-plan" and "storage-d1-apply"
}

service_name = "storage"
environment_name = "d1"
```

![image pipline environment details](media/image%20copy%202.png)

**How it Works**:

```terraform
resource "azuredevops_environment" "alz" {
  for_each   = var.environments
  name       = each.value.environment_name
  project_id = local.project_id
}
```

**Variable Structure** (from `locals.tf` in root):

```hcl
environments = {
  plan = {
    environment_name = "storage-d1-plan"
    service_connection_name = "sc-storage-d1-plan"
    service_connection_required_templates = [
      ".pipelines/ci-template.yaml",
      ".pipelines/cd-template.yaml"
    ]
  }
  apply = {
    environment_name = "storage-d1-apply"
    service_connection_name = "sc-storage-d1-apply"
    service_connection_required_templates = [
      ".pipelines/cd-template.yaml"
    ]
  }
}
```

**Explanation**:
- Creates two environments: `"storage-d1-plan"` and `"storage-d1-apply"`
- **Plan environment**: Used for `terraform plan` operations (read-only)
- **Apply environment**: Used for `terraform apply` operations (creates/modifies resources)
- Environments provide deployment tracking and can have approval gates
- The `service_connection_required_templates` will be used later to enforce which YAML templates can use each service connection

---

### service_connections.tf

![image list of service connections](media/image%20copy%203.png)

**Purpose**: Creates Azure service connections using OIDC (Workload Identity Federation) for secure, passwordless authentication to Azure.

**Relevant terraform.tfvars Configuration**:

```hcl
bootstrap_subscription_id = "b629af82-f93c-4bc8-9bb2-8e299758bbe7"

resource_names = {
  version_control_system_service_connection_plan = "sc-{{service_name}}-{{environment_name}}-plan"
  version_control_system_service_connection_apply = "sc-{{service_name}}-{{environment_name}}-apply"
  # Resolve to: "sc-storage-d1-plan" and "sc-storage-d1-apply"
}

apply_approvers = []
# If populated with emails like ["user@domain.com"], approvals would be required
```

**How it Works**:

```terraform
resource "azuredevops_serviceendpoint_azurerm" "alz" {
  for_each                               = var.environments
  project_id                             = local.project_id
  service_endpoint_name                  = each.value.service_connection_name
  description                            = "Managed by Terraform"
  service_endpoint_authentication_scheme = "WorkloadIdentityFederation"

  credentials {
    serviceprincipalid = var.managed_identity_client_ids[each.key]
  }

  azurerm_spn_tenantid      = var.azure_tenant_id
  azurerm_subscription_id   = var.azure_subscription_id
  azurerm_subscription_name = var.azure_subscription_name
}

resource "azuredevops_check_approval" "alz" {
  count                = length(var.approvers) == 0 ? 0 : 1
  project_id           = local.project_id
  target_resource_id   = azuredevops_serviceendpoint_azurerm.alz["apply"].id
  target_resource_type = "endpoint"

  requester_can_approve = length(var.approvers) == 1
  approvers = [
    azuredevops_group.alz_approvers.origin_id
  ]

  timeout = 43200
}

resource "azuredevops_check_exclusive_lock" "alz" {
  for_each             = var.environments
  project_id           = local.project_id
  target_resource_id   = azuredevops_serviceendpoint_azurerm.alz[each.key].id
  target_resource_type = "endpoint"
  timeout              = 43200
}

resource "azuredevops_check_required_template" "alz" {
  for_each             = var.environments
  project_id           = local.project_id
  target_resource_id   = azuredevops_serviceendpoint_azurerm.alz[each.key].id
  target_resource_type = "endpoint"

  dynamic "required_template" {
    for_each = each.value.service_connection_required_templates
    content {
      repository_type = "azuregit"
      repository_name = "${var.project_name}/${local.repository_name_templates}"
      repository_ref  = "refs/heads/main"
      template_path   = required_template.value
    }
  }
}
```

**Explanation**:

1. **Service Connections**: Creates two connections (`"sc-storage-d1-plan"` and `"sc-storage-d1-apply"`)
   - Uses OIDC authentication (no stored credentials)
   - Each connection is linked to a managed identity created in the `azure` module
   - Connects to subscription `"b629af82-f93c-4bc8-9bb2-8e299758bbe7"`

![image service connection detail](media/image%20copy%204.png)

Corresponding Azure Service Principal in the Azure Portal

![image service principal in azure portal. detail](media/image%20copy%204.png)


2. **Approval Check**: (Currently disabled because `apply_approvers = []`)
   - If approvers were specified, deployments using the "apply" connection would require manual approval
   - Timeout of 43200 minutes (30 days)

3. **Exclusive Lock**: Prevents concurrent deployments using the same service connection
   - Ensures only one pipeline can deploy at a time per environment
   - Prevents resource conflicts

![image service connection approvals and checks detail](media/image%20copy%206.png)

4. **Required Template Check**: Security enforcement
   - Plan connection can only be used from `ci-template.yaml` or `cd-template.yaml`
   - Apply connection can only be used from `cd-template.yaml`
   - Templates must exist in the `storage-d1-templates` repository (or main repo if separate templates disabled)
   - This prevents ad-hoc pipeline runs from bypassing security controls

![image service connection approvals and checks - required templates detail](media/image%20copy%207.png)

**Variable Mapping**:
- `var.environments` ← constructed in `locals.tf` from resource names
- `var.managed_identity_client_ids` ← output from `module.azure`
- `var.azure_subscription_id` ← `bootstrap_subscription_id`
- `var.approvers` ← `apply_approvers`

![image service connection detail](media/image%20copy%208.png)

---

### repository_module.tf

![image repository overview](media/image%20copy%209.png)


**Purpose**: Creates the main Git repository containing the Infrastructure as Code (IaC) module and CI/CD pipeline definitions.

**Relevant terraform.tfvars Configuration**:

```hcl
module_folder_path = "C:\\Users\\chpinoto\\workspace\\vbd\\bvg\\datahub\\storage-template"

resource_names = {
  version_control_system_repository = "{{service_name}}-{{environment_name}}"
  # Resolves to: "storage-d1"
}

create_branch_policies = true

apply_approvers = []
# If set to ["user1@domain.com", "user2@domain.com"], requires 1 reviewer
```

**How it Works**:

```terraform
resource "azuredevops_git_repository" "alz" {
  depends_on     = [azuredevops_environment.alz]
  project_id     = local.project_id
  name           = var.repository_name
  default_branch = "refs/heads/main"
  initialization {
    init_type = "Clean"
  }
}

resource "azuredevops_git_repository_file" "alz" {
  for_each            = var.repository_files
  repository_id       = azuredevops_git_repository.alz.id
  file                = each.key
  content             = each.value.content
  branch              = "refs/heads/main"
  commit_message      = "[skip ci]"
  overwrite_on_create = true
}

resource "azuredevops_branch_policy_min_reviewers" "alz" {
  depends_on = [azuredevops_git_repository_file.alz]
  project_id = local.project_id

  enabled  = length(var.approvers) > 1 && var.create_branch_policies
  blocking = true

  settings {
    reviewer_count                         = 1
    submitter_can_vote                     = false
    last_pusher_cannot_approve             = true
    allow_completion_with_rejects_or_waits = false
    on_push_reset_approved_votes           = true

    scope {
      repository_id  = azuredevops_git_repository.alz.id
      repository_ref = azuredevops_git_repository.alz.default_branch
      match_type     = "Exact"
    }
  }
}

resource "azuredevops_branch_policy_merge_types" "alz" {
  depends_on = [azuredevops_git_repository_file.alz]
  project_id = local.project_id

  enabled  = var.create_branch_policies
  blocking = true

  settings {
    allow_squash                  = true
    allow_rebase_and_fast_forward = false
    allow_basic_no_fast_forward   = false
    allow_rebase_with_merge       = false

    scope {
      repository_id  = azuredevops_git_repository.alz.id
      repository_ref = azuredevops_git_repository.alz.default_branch
      match_type     = "Exact"
    }
  }
}

resource "azuredevops_branch_policy_build_validation" "alz" {
  depends_on = [azuredevops_git_repository_file.alz]
  project_id = local.project_id

  enabled  = var.create_branch_policies
  blocking = true

  settings {
    display_name        = "Terraform Validation"
    build_definition_id = azuredevops_build_definition.alz["ci"].id
    valid_duration      = 720

    scope {
      repository_id  = azuredevops_git_repository.alz.id
      repository_ref = azuredevops_git_repository.alz.default_branch
      match_type     = "Exact"
    }
  }
}
```

**Repository Files Structure** (from `locals.files.tf`):

The repository contains a combination of:

1. **Pipeline YAML files**:
   ```
   .pipelines/ci.yaml
   .pipelines/cd.yaml
   ```

2. **Terraform module files** from `C:\Users\chpinoto\workspace\vbd\bvg\datahub\storage-template`:
   ```
   main.tf
   variables.tf
   outputs.tf
   providers.tf
   ... (all files from the starter module)
   ```

3. **Template files** (if `use_separate_repository_for_templates = false`):
   ```
   .pipelines/ci-template.yaml
   .pipelines/cd-template.yaml
   .pipelines/helpers/*
   ```

**Explanation**:

1. **Repository Creation**: Creates repo named `"storage-d1"`
   - Initialized with a clean main branch
   - Waits for environments to be created first

2. **File Population**: Copies all files into the repository
   - Terraform module files have backend configuration enabled automatically
   - Pipeline YAML files are generated from templates
   - Uses `[skip ci]` in commit message to prevent triggering builds during initial setup

3. **Branch Policy - Minimum Reviewers**: (Currently disabled - only activates with 2+ approvers)
   - Would require 1 code review before merging to main
   - Submitter cannot approve their own changes
   - Last person who pushed code cannot approve
   - Approvals reset when new code is pushed

![image repository policy overview](media/image%20copy%2010.png)

4. **Branch Policy - Merge Types**: ✅ **Enabled**
   - Only allows squash merges (keeps history clean)
   - Blocks rebase, fast-forward, and other merge types

![image repository policy overview](media/image%20copy%2011.png)

5. **Branch Policy - Build Validation**: ✅ **Enabled**
   - Pull requests to main must pass the CI pipeline
   - Validation remains valid for 720 minutes (12 hours)
   - Ensures code is tested before merge

![image repository policy overview](media/image%20copy%2012.png)

**Variable Mapping**:
- `var.repository_name` ← `resource_names.version_control_system_repository`
- `var.repository_files` ← constructed in `locals.files.tf` from module files + pipeline files
- `var.create_branch_policies` ← `create_branch_policies`
- `var.approvers` ← `apply_approvers`

---

### repository_templates.tf

**Purpose**: Creates a separate security-isolated repository for pipeline template files (optional but recommended).

![image repository pipeline templates overview](media/image%20copy%2013.png)


**Relevant terraform.tfvars Configuration**:

```hcl
use_separate_repository_for_templates = true

resource_names = {
  version_control_system_repository_templates = "{{service_name}}-{{environment_name}}-templates"
  # Resolves to: "storage-d1-templates"
}

create_branch_policies = true
```

**How it Works**:

```terraform
resource "azuredevops_git_repository" "alz_templates" {
  count          = var.use_template_repository ? 1 : 0
  project_id     = local.project_id
  name           = var.repository_name_templates
  default_branch = "refs/heads/main"
  initialization {
    init_type = "Clean"
  }
}

resource "azuredevops_git_repository_file" "alz_templates" {
  for_each            = var.use_template_repository ? var.template_repository_files : {}
  repository_id       = azuredevops_git_repository.alz_templates[0].id
  file                = each.key
  content             = each.value.content
  branch              = "refs/heads/main"
  commit_message      = "[skip ci]"
  overwrite_on_create = true
}

resource "azuredevops_branch_policy_min_reviewers" "alz_templates" {
  count      = var.use_template_repository ? 1 : 0
  depends_on = [azuredevops_git_repository_file.alz_templates]
  project_id = local.project_id

  enabled  = length(var.approvers) > 1 && var.create_branch_policies
  blocking = true

  settings {
    reviewer_count                         = 1
    submitter_can_vote                     = false
    last_pusher_cannot_approve             = true
    allow_completion_with_rejects_or_waits = false
    on_push_reset_approved_votes           = true

    scope {
      repository_id  = azuredevops_git_repository.alz_templates[0].id
      repository_ref = azuredevops_git_repository.alz_templates[0].default_branch
      match_type     = "Exact"
    }
  }
}

resource "azuredevops_branch_policy_merge_types" "alz_templates" {
  count      = var.use_template_repository ? 1 : 0
  depends_on = [azuredevops_git_repository_file.alz_templates]
  project_id = local.project_id

  enabled  = var.create_branch_policies
  blocking = true

  settings {
    allow_squash                  = true
    allow_rebase_and_fast_forward = false
    allow_basic_no_fast_forward   = false
    allow_rebase_with_merge       = false

    scope {
      repository_id  = azuredevops_git_repository.alz_templates[0].id
      repository_ref = azuredevops_git_repository.alz_templates[0].default_branch
      match_type     = "Exact"
    }
  }
}
```

**Template Repository Files** (from `locals.files.tf`):

```
.pipelines/ci-template.yaml
.pipelines/cd-template.yaml
.pipelines/helpers/terraform-init.yaml
.pipelines/helpers/terraform-plan.yaml
.pipelines/helpers/terraform-apply.yaml
.pipelines/helpers/terraform-installer.yaml
```

**Explanation**:

1. **Security Isolation**: Creates `"storage-d1-templates"` repository
   - Separates pipeline logic from infrastructure code
   - Service connections can only execute pipelines from approved templates in this repo
   - Prevents developers from modifying pipeline behavior without approval
   - Changes to templates require separate approval process

2. **Template Files**: Contains reusable YAML templates
   - `ci-template.yaml`: Terraform validation and plan logic
   - `cd-template.yaml`: Terraform apply logic with approvals
   - Helper templates: Common steps (init, plan, apply, install)

3. **Branch Policies**: Same as main repository
   - Squash merge only
   - Optionally requires code reviews (if 2+ approvers configured)

**Why Separate Templates?**

This is a security best practice:
- Main repo (`storage-d1`): Developers can modify Terraform code
- Templates repo (`storage-d1-templates`): Only approved users can modify deployment logic
- Service connections enforce that only templates from the templates repo can be used
- Prevents privilege escalation (developer can't modify pipeline to bypass controls)

**Variable Mapping**:
- `var.use_template_repository` ← `use_separate_repository_for_templates`
- `var.repository_name_templates` ← `resource_names.version_control_system_repository_templates`
- `var.template_repository_files` ← constructed in `locals.files.tf`

---

### variable_group.tf

![image pipeline library variable groups overview](media/image%20copy%2014.png)

**Purpose**: Creates a variable group containing Terraform backend configuration shared across pipelines.

**Relevant terraform.tfvars Configuration**:

```hcl
bootstrap_subscription_id = "b629af82-f93c-4bc8-9bb2-8e299758bbe7"
bootstrap_location = "germanywestcentral"
storage_account_replication_type = "ZRS"

resource_names = {
  version_control_system_variable_group = "{{service_name}}-{{environment_name}}"
  resource_group_state = "rg-{{service_name}}-{{environment_name}}-state-{{azure_location}}-{{postfix_number}}"
  storage_account = "sto{{service_name_short}}{{environment_name_short}}{{azure_location_short}}{{postfix_number}}{{random_string}}"
  storage_container = "{{environment_name}}-tfstate"
  # Resolve to:
  # - variable_group_name: "storage-d1"
  # - resource_group: "rg-storage-d1-state-germanywestcentral-1"
  # - storage_account: "stostd1gw1<random>" (exact name determined at runtime)
  # - container: "d1-tfstate"
}

service_name = "storage"
environment_name = "d1"
postfix_number = 1
```

![image pipeline library variable groups storage account overview](media/image%20copy%2015.png)

**How it Works**:

```terraform
resource "azuredevops_variable_group" "example" {
  project_id   = local.project_id
  name         = var.variable_group_name
  description  = var.variable_group_name
  allow_access = true

  variable {
    name  = "BACKEND_AZURE_RESOURCE_GROUP_NAME"
    value = var.backend_azure_resource_group_name
  }

  variable {
    name  = "BACKEND_AZURE_STORAGE_ACCOUNT_NAME"
    value = var.backend_azure_storage_account_name
  }

  variable {
    name  = "BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME"
    value = var.backend_azure_storage_account_container_name
  }
}
```

**Explanation**:

Creates variable group `"storage-d1"` with three variables:

1. **BACKEND_AZURE_RESOURCE_GROUP_NAME**: `"rg-storage-d1-state-germanywestcentral-1"`
   - Resource group containing the Terraform state storage account
   - Created in the `azure` module in the bootstrap subscription

2. **BACKEND_AZURE_STORAGE_ACCOUNT_NAME**: e.g., `"stostd1gw1abc123"`
   - Storage account name (includes random string for global uniqueness)
   - Uses ZRS replication for state file resilience
   - Created in the `azure` module

3. **BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME**: `"d1-tfstate"`
   - Blob container within the storage account
   - Stores the `terraform.tfstate` file

**Pipeline Usage**:

Pipelines reference these variables to configure the Terraform backend:

```yaml
- group: storage-d1

steps:
  - script: |
      terraform init \
        -backend-config="resource_group_name=$(BACKEND_AZURE_RESOURCE_GROUP_NAME)" \
        -backend-config="storage_account_name=$(BACKEND_AZURE_STORAGE_ACCOUNT_NAME)" \
        -backend-config="container_name=$(BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME)"
```

**Variable Mapping**:
- `var.variable_group_name` ← `resource_names.version_control_system_variable_group`
- `var.backend_azure_resource_group_name` ← output from `module.azure`
- `var.backend_azure_storage_account_name` ← output from `module.azure`
- `var.backend_azure_storage_account_container_name` ← `resource_names.storage_container`

---

### groups.tf

**Purpose**: Creates an Azure DevOps security group for deployment approvers and manages membership.

![image permissions groups overview](media/image%20copy%2017.png)

**Relevant terraform.tfvars Configuration**:

```hcl
apply_approvers = []
# Example if populated:
# apply_approvers = [
#   "chpinoto@microsoft.com",
#   "colleague@microsoft.com"
# ]

resource_names = {
  version_control_system_group = "{{service_name}}-{{environment_name}}-approvers"
  # Resolves to: "storage-d1-approvers"
}
```

**How it Works**:

```terraform
resource "azuredevops_group" "alz_approvers" {
  scope        = local.project_id
  display_name = var.group_name
  description  = "Approvers for the Landing Zone Terraform Apply"
}

data "azuredevops_users" "alz" {
  for_each       = { for approver in var.approvers : approver => approver }
  principal_name = each.key
  lifecycle {
    postcondition {
      condition     = length(self.users) > 0
      error_message = "No user account found for ${each.value}, check you have entered a valid user principal name..."
    }
  }
}

locals {
  approvers = toset(flatten([for approver in data.azuredevops_users.alz :
    [for user in approver.users : user.descriptor]
  ]))
}

resource "azuredevops_group_membership" "alz_approvers" {
  group   = azuredevops_group.alz_approvers.descriptor
  members = local.approvers
}
```

**Explanation**:

1. **Group Creation**: Creates group `"storage-d1-approvers"`
   - Scoped to the `storagetest` project
   - Used for approval workflows on deployments

![image permissions groups overview](media/image%20copy%2016.png)


2. **User Lookup**: (Currently empty because `apply_approvers = []`)
   - If approvers were specified, looks up each user by email/UPN
   - Validates that each user exists in Azure DevOps
   - Fails if any specified user cannot be found

3. **Group Membership**: Adds found users to the group
   - Uses user descriptors (internal Azure DevOps IDs)
   - Currently has no members

**If Approvers Were Configured**:

```hcl
apply_approvers = [
  "chpinoto@microsoft.com",
  "colleague@microsoft.com"
]
```

Would result in:
- Group `"storage-d1-approvers"` with 2 members
- Approval check on `"sc-storage-d1-apply"` service connection requiring one of these users to approve
- Manual approval step in CD pipeline before `terraform apply` runs

**Variable Mapping**:
- `var.group_name` ← `resource_names.version_control_system_group`
- `var.approvers` ← `apply_approvers`

---

### pipeline.tf

**Purpose**: Creates Azure DevOps pipelines (CI/CD) and authorizes them to use environments, service connections, and agent pools.

**Relevant terraform.tfvars Configuration**:

```hcl
resource_names = {
  version_control_system_pipeline_name_ci = "01 Simple Storage VM Continuous Integration"
  version_control_system_pipeline_name_cd = "02 Simple Storage VM Continuous Delivery"
}

use_self_hosted_agents = true
```

**How it Works**:

```terraform
resource "azuredevops_build_definition" "alz" {
  for_each   = local.pipelines
  project_id = local.project_id
  name       = each.value.pipeline_name

  ci_trigger {
    use_yaml = true
  }

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.alz.id
    branch_name = azuredevops_git_repository.alz.default_branch
    yml_path    = each.value.file
  }
}

resource "azuredevops_pipeline_authorization" "alz_environment" {
  for_each    = local.pipeline_environments_map
  project_id  = local.project_id
  resource_id = each.value.environment_id
  type        = "environment"
  pipeline_id = each.value.pipeline_id
}

resource "azuredevops_pipeline_authorization" "alz_service_connection" {
  for_each    = local.pipeline_service_connections_map
  project_id  = local.project_id
  resource_id = each.value.service_connection_id
  type        = "endpoint"
  pipeline_id = each.value.pipeline_id
}

resource "azuredevops_pipeline_authorization" "alz_agent_pool" {
  for_each    = var.use_self_hosted_agents ? local.pipelines : {}
  project_id  = local.project_id
  resource_id = azuredevops_agent_queue.alz[0].id
  type        = "queue"
  pipeline_id = azuredevops_build_definition.alz[each.key].id
}
```

**Pipeline Configuration** (from `locals.pipelines.tf` in root):

```hcl
pipelines = {
  ci = {
    pipeline_name      = "01 Simple Storage VM Continuous Integration"
    pipeline_file_name = ".pipelines/ci.yaml"
    environment_keys   = ["plan"]
    service_connection_keys = ["plan"]
  }
  cd = {
    pipeline_name      = "02 Simple Storage VM Continuous Delivery"
    pipeline_file_name = ".pipelines/cd.yaml"
    environment_keys   = ["plan", "apply"]
    service_connection_keys = ["plan", "apply"]
  }
}
```

**Explanation**:

1. **Pipeline Creation**: Creates two pipelines

   **CI Pipeline** (`"01 Simple Storage VM Continuous Integration"`):
   - Triggered automatically on pull requests and commits to main
   - Runs from `.pipelines/ci.yaml`
   - Uses `"storage-d1-plan"` environment
   - Uses `"sc-storage-d1-plan"` service connection (read-only)
   - Executes: `terraform init`, `terraform validate`, `terraform plan`
   - Purpose: Validate infrastructure changes before merge

   **CD Pipeline** (`"02 Simple Storage VM Continuous Delivery"`):
   - Runs from `.pipelines/cd.yaml`
   - Uses both plan and apply environments
   - Uses both service connections
   - Executes:
     - Stage 1 (Plan): `terraform plan` with plan service connection
     - Stage 2 (Apply): `terraform apply` with apply service connection (requires approval if configured)
   - Purpose: Deploy infrastructure changes to Azure

2. **Environment Authorization**: Grants pipelines access to environments
   - CI pipeline → `storage-d1-plan` environment
   - CD pipeline → `storage-d1-plan` + `storage-d1-apply` environments

3. **Service Connection Authorization**: Grants pipelines access to Azure credentials
   - CI pipeline → `sc-storage-d1-plan` (Reader role)
   - CD pipeline → `sc-storage-d1-plan` + `sc-storage-d1-apply` (Reader + Contributor roles)

4. **Agent Pool Authorization**: Grants pipelines access to self-hosted agents
   - Both pipelines → `storage-d1` agent pool
   - Only created when `use_self_hosted_agents = true`

**Variable Mapping**:
- `local.pipelines` ← constructed in `locals_pipelines.tf` from resource names
- `var.use_self_hosted_agents` ← `use_self_hosted_agents`

---

### locals.tf

**Purpose**: Defines local variables and constructs the organization URL based on configuration.

**Relevant terraform.tfvars Configuration**:

```hcl
azure_devops_organization_name = "cptdx"
azure_devops_use_organisation_legacy_url = false

use_separate_repository_for_templates = true
```

**How it Works**:

```terraform
locals {
  organization_url = startswith(lower(var.organization_name), "https://") || startswith(lower(var.organization_name), "http://") ? 
    var.organization_name : 
    (var.use_legacy_organization_url ? 
      "https://${var.organization_name}.visualstudio.com" : 
      "https://dev.azure.com/${var.organization_name}")
}

locals {
  apply_key = "apply"
}

locals {
  authentication_scheme_workload_identity_federation = "WorkloadIdentityFederation"
}

locals {
  default_branch = "refs/heads/main"
}

locals {
  repository_name_templates = var.use_template_repository ? var.repository_name_templates : var.repository_name
}
```

**Explanation**:

1. **organization_url**: `"https://dev.azure.com/cptdx"`
   - If `azure_devops_use_organisation_legacy_url = true`, would be `"https://cptdx.visualstudio.com"`
   - If organization_name already starts with http/https, uses it as-is
   - Used by self-hosted agents to connect to Azure DevOps

2. **apply_key**: `"apply"`
   - Consistent key used throughout code to reference the apply environment/identity

3. **authentication_scheme_workload_identity_federation**: `"WorkloadIdentityFederation"`
   - Constant for OIDC authentication (passwordless, certificate-less)

4. **default_branch**: `"refs/heads/main"`
   - Standard Git reference format for the main branch

5. **repository_name_templates**: `"storage-d1-templates"`
   - If `use_separate_repository_for_templates = false`, would be `"storage-d1"` (same as main repo)
   - Determines where pipeline templates are stored

**Variable Mapping**:
- `var.organization_name` ← `azure_devops_organization_name`
- `var.use_legacy_organization_url` ← `azure_devops_use_organisation_legacy_url`
- `var.use_template_repository` ← `use_separate_repository_for_templates`

---

### locals_pipelines.tf

**Purpose**: Transforms pipeline configuration into structured data used to create pipeline authorizations.

**How it Works**:

```terraform
locals {
  pipelines = { for key, value in var.pipelines : key => {
    pipeline_name = value.pipeline_name
    file          = azuredevops_git_repository_file.alz[value.pipeline_file_name].file
    environments = [for environment_key in value.environment_keys :
      {
        environment_key = environment_key
        environment_id  = azuredevops_environment.alz[environment_key].id
      }
    ]
    service_connections = [for service_connection_key in value.service_connection_keys :
      {
        service_connection_key = service_connection_key
        service_connection_id  = azuredevops_serviceendpoint_azurerm.alz[service_connection_key].id
      }
    ]
    }
  }

  pipeline_environments = flatten([for pipeline_key, pipeline in local.pipelines :
    [for environment in pipeline.environments : {
      pipeline_key    = pipeline_key
      environment_key = environment.environment_key
      pipeline_id     = azuredevops_build_definition.alz[pipeline_key].id
      environment_id  = environment.environment_id
      }
    ]
  ])

  pipeline_service_connections = flatten([for pipeline_key, pipeline in local.pipelines :
    [for service_connection in pipeline.service_connections : {
      pipeline_key           = pipeline_key
      service_connection_key = service_connection.service_connection_key
      pipeline_id            = azuredevops_build_definition.alz[pipeline_key].id
      service_connection_id  = service_connection.service_connection_id
      }
    ]
  ])

  pipeline_environments_map = { for pipeline_environment in local.pipeline_environments : "${pipeline_environment.pipeline_key}-${pipeline_environment.environment_key}" => {
    pipeline_id    = pipeline_environment.pipeline_id
    environment_id = pipeline_environment.environment_id
    }
  }

  pipeline_service_connections_map = { for pipeline_service_connection in local.pipeline_service_connections : "${pipeline_service_connection.pipeline_key}-${pipeline_service_connection.service_connection_key}" => {
    pipeline_id           = pipeline_service_connection.pipeline_id
    service_connection_id = pipeline_service_connection.service_connection_id
    }
  }
}
```

**Data Transformation Example**:

**Input** (from root `locals.pipelines.tf`):
```hcl
pipelines = {
  ci = {
    pipeline_name = "01 Simple Storage VM Continuous Integration"
    pipeline_file_name = ".pipelines/ci.yaml"
    environment_keys = ["plan"]
    service_connection_keys = ["plan"]
  }
  cd = {
    pipeline_name = "02 Simple Storage VM Continuous Delivery"
    pipeline_file_name = ".pipelines/cd.yaml"
    environment_keys = ["plan", "apply"]
    service_connection_keys = ["plan", "apply"]
  }
}
```

**Output** (`local.pipeline_environments_map`):
```hcl
{
  "ci-plan" = {
    pipeline_id    = "<ci_pipeline_id>"
    environment_id = "<plan_environment_id>"
  }
  "cd-plan" = {
    pipeline_id    = "<cd_pipeline_id>"
    environment_id = "<plan_environment_id>"
  }
  "cd-apply" = {
    pipeline_id    = "<cd_pipeline_id>"
    environment_id = "<apply_environment_id>"
  }
}
```

**Output** (`local.pipeline_service_connections_map`):
```hcl
{
  "ci-plan" = {
    pipeline_id           = "<ci_pipeline_id>"
    service_connection_id = "<plan_service_connection_id>"
  }
  "cd-plan" = {
    pipeline_id           = "<cd_pipeline_id>"
    service_connection_id = "<plan_service_connection_id>"
  }
  "cd-apply" = {
    pipeline_id           = "<cd_pipeline_id>"
    service_connection_id = "<apply_service_connection_id>"
  }
}
```

**Explanation**:

This file performs complex data transformations to create authorization mappings:

1. **local.pipelines**: Enriches pipeline configuration with resource IDs
   - Links pipeline file paths to actual file resources
   - Links environment keys to environment IDs
   - Links service connection keys to service connection IDs

2. **local.pipeline_environments**: Flattens to list of pipeline-environment pairs
   - CI has 1 pair: CI ↔ plan
   - CD has 2 pairs: CD ↔ plan, CD ↔ apply

3. **local.pipeline_service_connections**: Flattens to list of pipeline-service connection pairs
   - CI has 1 pair: CI ↔ plan connection
   - CD has 2 pairs: CD ↔ plan connection, CD ↔ apply connection

4. **Maps**: Convert lists to maps with unique keys for `for_each` loops
   - Enables creating authorization resources with proper relationships

**Usage in pipeline.tf**:
```terraform
resource "azuredevops_pipeline_authorization" "alz_environment" {
  for_each    = local.pipeline_environments_map
  # Creates 3 authorizations: ci-plan, cd-plan, cd-apply
  ...
}
```

---

## Complete Configuration Flow

Here's how a complete deployment flows from `terraform.tfvars` through the system:

### 1. User Configuration (terraform.tfvars)

```hcl
azure_devops_organization_name = "cptdx"
azure_devops_project_name = "storagetest"
service_name = "storage"
environment_name = "d1"
use_self_hosted_agents = true
use_separate_repository_for_templates = true
apply_approvers = []
```

### 2. Variable Declaration (variables.tf)

Variables are declared with types and validation rules.

### 3. Local Transformation (locals.tf, locals.pipelines.tf, locals.files.tf)

**Name Resolution**:
```hcl
resource_names.version_control_system_repository
# "storage-d1"
```

**Environment Construction**:
```hcl
environments = {
  plan = {
    environment_name = "storage-d1-plan"
    service_connection_name = "sc-storage-d1-plan"
    ...
  }
  apply = { ... }
}
```

**File Preparation**:
```hcl
repository_files = {
  ".pipelines/ci.yaml" = { content = "..." }
  ".pipelines/cd.yaml" = { content = "..." }
  "main.tf" = { content = "..." }
  ...
}

template_repository_files = {
  ".pipelines/ci-template.yaml" = { content = "..." }
  ".pipelines/cd-template.yaml" = { content = "..." }
  ...
}
```

### 4. Module Invocation (main.tf)

```hcl
module "azure_devops" {
  source = "./modules/azure_devops"
  
  organization_name = "cptdx"
  project_name = "storagetest"
  environments = local.environments
  repository_name = "storage-d1"
  repository_files = local.repository_files
  use_template_repository = true
  repository_name_templates = "storage-d1-templates"
  template_repository_files = local.template_repository_files
  ...
}
```

### 5. Resource Creation (modules/azure_devops/*.tf)

**Execution Order**:

1. **project.tf**: Create/lookup project `"storagetest"`
2. **agent_pool.tf**: Create agent pool `"storage-d1"`
3. **groups.tf**: Create approvers group `"storage-d1-approvers"` (currently empty)
4. **environment.tf**: Create environments `"storage-d1-plan"` and `"storage-d1-apply"`
5. **service_connections.tf**: Create service connections with OIDC auth
   - Add exclusive locks
   - Add required template checks
   - (Skip approval check - no approvers configured)
6. **repository_module.tf**: Create main repo `"storage-d1"`
   - Populate with module files and pipeline YAMLs
   - Add branch policies (merge type, build validation)
7. **repository_templates.tf**: Create templates repo `"storage-d1-templates"`
   - Populate with pipeline template files
   - Add branch policies
8. **variable_group.tf**: Create variable group `"storage-d1"` with backend config
9. **pipeline.tf**: Create CI and CD pipelines
   - Authorize pipelines to use environments
   - Authorize pipelines to use service connections
   - Authorize pipelines to use agent pool

### 6. Result

**Azure DevOps Resources Created**:

- **Project**: `storagetest`
- **Repositories** (2):
  - `storage-d1` (main infrastructure code)
  - `storage-d1-templates` (pipeline templates)
- **Environments** (2):
  - `storage-d1-plan` (for validation)
  - `storage-d1-apply` (for deployment)
- **Service Connections** (2):
  - `sc-storage-d1-plan` (OIDC to Azure with Reader role)
  - `sc-storage-d1-apply` (OIDC to Azure with Contributor role)
- **Agent Pool**: `storage-d1` (2 self-hosted agents in Azure Container Instances)
- **Pipelines** (2):
  - `01 Simple Storage VM Continuous Integration`
  - `02 Simple Storage VM Continuous Delivery`
- **Variable Group**: `storage-d1` (Terraform backend configuration)
- **Security Group**: `storage-d1-approvers` (currently empty)
- **Branch Policies**: Enforced on both repositories

**Security Controls**:

✅ OIDC authentication (no stored credentials)  
✅ Separate plan/apply identities with different RBAC  
✅ Service connections restricted to specific pipeline templates  
✅ Exclusive locks prevent concurrent deployments  
✅ Branch policies enforce code review and CI validation  
✅ Template repository isolation prevents pipeline tampering  

---

## Summary

The `azure_devops` module creates a complete, secure CI/CD platform for Infrastructure as Code with:

- **Separation of Concerns**: Read-only plan operations vs. privileged apply operations
- **Security by Default**: OIDC auth, template enforcement, exclusive locks
- **Scalability**: Self-hosted agents in Azure Container Instances with zone redundancy
- **Compliance**: Branch policies, approval workflows, audit trails
- **Flexibility**: Configurable through simple `terraform.tfvars` variables

All configuration flows from user-friendly variables in `terraform.tfvars`, through transformations in local values, into the module which creates properly secured Azure DevOps resources.
