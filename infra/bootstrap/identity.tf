# Passwordless GitHub Actions -> Azure login (OIDC workload identity federation).
data "azuread_client_config" "me" {}

data "github_repository" "repo" {
  full_name = "${var.github_owner}/${var.github_repo}"
}

data "github_user" "owner" {
  username = var.github_owner
}

locals {
  # This repo uses GitHub's immutable subject format: owner and repo carry their numeric IDs,
  # so renaming the repo can't hand its Azure access to someone else.
  subject_prefix = "repo:${var.github_owner}@${data.github_user.owner.id}/${var.github_repo}@${data.github_repository.repo.repo_id}"

  federated_subjects = merge(
    {
      "gh-main" = "${local.subject_prefix}:ref:refs/heads/main" # jobs on main without an environment
      "gh-pr"   = "${local.subject_prefix}:pull_request"        # terraform plan on pull requests
    },
    { for e in var.deploy_environments : "gh-env-${e}" => "${local.subject_prefix}:environment:${e}" },
  )
}

resource "azuread_application" "gh" {
  display_name = "gh-oidc-${var.github_repo}"
  owners       = [data.azuread_client_config.me.object_id]
}

resource "azuread_service_principal" "gh" {
  client_id = azuread_application.gh.client_id
  owners    = [data.azuread_client_config.me.object_id]
}

resource "azuread_application_federated_identity_credential" "gh" {
  for_each       = local.federated_subjects
  application_id = azuread_application.gh.id
  display_name   = each.key
  issuer         = "https://token.actions.githubusercontent.com"
  audiences      = ["api://AzureADTokenExchange"]
  subject        = each.value
}

# --- What CI may do ---------------------------------------------------------
resource "azurerm_role_assignment" "ci_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.gh.object_id
}

# Contributor can't grant roles, but lab Terraform must (e.g. VM identity -> AcrPull).
# This lets CI assign ONLY the roles listed below, nothing else (no Owner, no escalation).
locals {
  ci_assignable_roles = {
    AcrPull = "7f951dda-4ed3-4680-a7ca-43fe172d538d"
    AcrPush = "8311e382-0749-4cb8-b61a-304f252e45ec"
  }
  ci_roles_guid_list = join(", ", values(local.ci_assignable_roles))
}

resource "azurerm_role_assignment" "ci_rbac_admin_limited" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azuread_service_principal.gh.object_id
  condition_version    = "2.0"
  condition            = <<-EOT
    (
     (!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'}))
     OR
     (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.ci_roles_guid_list}})
    )
    AND
    (
     (!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'}))
     OR
     (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.ci_roles_guid_list}})
    )
  EOT
}

resource "azurerm_role_assignment" "ci_state" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.gh.object_id
}
