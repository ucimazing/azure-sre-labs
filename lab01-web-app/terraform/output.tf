output "public_ip" {
  value = azurerm_public_ip.vmip.ip_address
}
output "ssh" {
  value = "ssh azureuser@${azurerm_public_ip.vmip.ip_address}"
}
