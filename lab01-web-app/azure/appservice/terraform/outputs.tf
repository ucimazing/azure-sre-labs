output "url" {
  value = "https://${azurerm_linux_web_app.app.default_hostname}"
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "webapp_name" {
  value = azurerm_linux_web_app.app.name
}

output "resource_group" {
  value = azurerm_resource_group.rg.name
}
