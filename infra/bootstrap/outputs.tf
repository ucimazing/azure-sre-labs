output "state_rg" {
  value = azurerm_resource_group.tfstate.name
}

output "state_sa" {
  value = azurerm_storage_account.tfstate.name
}

output "state_container" {
  value = azurerm_storage_container.tfstate.name
}

output "ci_client_id" {
  value = azuread_application.gh.client_id
}

output "oidc_subjects" {
  value = local.federated_subjects
}
