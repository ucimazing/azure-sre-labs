output "public_ip" {
  value = azurerm_public_ip.vmip.ip_address
}
output "ssh" {
  value = "ssh azureuser@${azurerm_public_ip.vmip.ip_address}"
}

output "key_vault_name" {
  value = azurerm_key_vault.kv.name
}

# Ansible passes this to the VM's metadata service to say which identity to get a token for.
output "vm_identity_client_id" {
  value = azurerm_user_assigned_identity.vm.client_id
}
