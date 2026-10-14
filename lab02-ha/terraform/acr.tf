resource "random_string" "acr" {
  length  = 6
  special = false
  upper   = false
}
resource "azurerm_container_registry" "lab02-acr" {
  name                = "acrlab02${random_string.acr.result}"
  sku                 = "Basic"
  admin_enabled       = false
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}
resource "azurerm_role_assignment" "ci_push" {
  scope                = azurerm_container_registry.lab02-acr.id
  role_definition_name = "AcrPush"
  principal_id         = var.ci_object_id
}
output "acr_name" {
  value = azurerm_container_registry.lab02-acr.name
}
output "acr_login_server" {
  value = azurerm_container_registry.lab02-acr.login_server
}