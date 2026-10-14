# The "badge" every app server will wear. Created now, attached to the scale set in H5:
#   identity { type = "UserAssigned", identity_ids = [azurerm_user_assigned_identity.app.id] }
# User-assigned, so every instance (including ones autoscale creates later) shares it,
# and its rights survive if the scale set is rebuilt.
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-lab02-app"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# Read the DB password, nothing more (least privilege).
resource "azurerm_role_assignment" "app_kv" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# Pull images from the Lab 2 registry, but never push.
resource "azurerm_role_assignment" "app_acr" {
  scope                = azurerm_container_registry.lab02-acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# H5 needs both: the .id to attach the identity, the client ID to ask for tokens on the VM.
output "app_identity_id" {
  value = azurerm_user_assigned_identity.app.id
}

output "app_identity_client_id" {
  value = azurerm_user_assigned_identity.app.client_id
}
