# Key Vault holds the DB password. Access is by Azure RBAC roles only, never by keys.

# Reads facts about the current login. Here we only need the tenant ID (same for you and CI).
data "azurerm_client_config" "current" {}

resource "random_string" "kv" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault" "kv" {
  name                = "kv-lab02-${random_string.kv.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard" # lowercase, case-sensitive

  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # lab only, so destroy can fully remove it. In prod: true.

  tags = local.tags
}

# Lab 1 lesson: name the identities EXPLICITLY. Never "whoever runs Terraform".
# You: so you can read secrets when debugging.
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.admin_object_id
}

# CI: will run this Terraform from H8 on, and must be able to write the secret.
resource "azurerm_role_assignment" "kv_ci" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.ci_object_id
}

# New roles take 1-5 minutes to reach Key Vault. Without this pause the secret write gets 403.
resource "time_sleep" "kv_rbac" {
  create_duration = "120s"
  depends_on      = [azurerm_role_assignment.kv_admin, azurerm_role_assignment.kv_ci]
}

resource "azurerm_key_vault_secret" "postgres" {
  name         = "postgres-password"
  value        = random_password.postgres.result
  key_vault_id = azurerm_key_vault.kv.id

  # Lab 1 lesson: depend on BOTH roles, so destroy deletes the secret BEFORE removing the roles.
  depends_on = [time_sleep.kv_rbac, azurerm_role_assignment.kv_admin, azurerm_role_assignment.kv_ci]
}

output "key_vault_name" {
  value = azurerm_key_vault.kv.name
}
