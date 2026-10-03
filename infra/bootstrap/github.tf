# Repo variables the workflows read. Not secrets: OIDC needs only IDs.
locals {
  gh_variables = {
    AZURE_CLIENT_ID       = azuread_application.gh.client_id
    AZURE_TENANT_ID       = var.tenant_id
    AZURE_SUBSCRIPTION_ID = var.subscription_id
    TFSTATE_RG            = azurerm_resource_group.tfstate.name
    TFSTATE_SA            = azurerm_storage_account.tfstate.name
    TFSTATE_CONTAINER     = azurerm_storage_container.tfstate.name
  }
}

# The three AZURE_* variables already exist (they point at the old account): adopt them.
import {
  for_each = toset(["AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID"])
  to       = github_actions_variable.repo[each.key]
  id       = "${var.github_repo}:${each.key}"
}

resource "github_actions_variable" "repo" {
  for_each      = local.gh_variables
  repository    = var.github_repo
  variable_name = each.key
  value         = each.value
}

# A deploy environment = a manual approval gate + only `main` may deploy.
resource "github_repository_environment" "deploy" {
  for_each    = toset(var.deploy_environments)
  repository  = var.github_repo
  environment = each.key

  reviewers {
    users = [data.github_user.owner.id]
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "main_only" {
  for_each       = github_repository_environment.deploy
  repository     = var.github_repo
  environment    = each.value.environment
  branch_pattern = "main"
}
