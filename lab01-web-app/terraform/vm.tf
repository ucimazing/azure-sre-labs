resource "azurerm_network_interface" "nic" {
  location            = var.location
  name                = "vmnic"
  resource_group_name = azurerm_resource_group.rglab01.name
  ip_configuration {
    name                          = "config"
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.vmsubnet.id
    public_ip_address_id = azurerm_public_ip.vmip.id
  }

}
resource "azurerm_linux_virtual_machine" "vm" {
  size = var.vm-size
  name = "vmm"
  location = var.location
  resource_group_name = azurerm_resource_group.rglab01.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  admin_username = "azureuser"
  disable_password_authentication = true
  admin_ssh_key {
    public_key = file(pathexpand("~/.ssh/id_ed25519.pub"))
    username   = "azureuser"
  }
  os_disk {
    caching = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
  source_image_reference {
    offer     = "ubuntu-24_04-lts"
    publisher = "Canonical"
    version   = "latest"
    sku = "server"
  }
  tags = local.tags
  boot_diagnostics {}
}
