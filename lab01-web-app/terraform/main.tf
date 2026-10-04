locals {
  tags = { lab = "01", owner = "ucimazing", env = "lab" }
}
resource "azurerm_resource_group" "rglab01" {
  location = var.location
  tags     = local.tags
  name     = "rg-lab01-vm"
}
resource "azurerm_virtual_network" "vnetlab01" {
  name                = "vmvnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.rglab01.name
  address_space       = ["10.10.0.0/16"]
  tags                = local.tags
}
resource "azurerm_subnet" "vmsubnet" {
  name                 = "vmsub"
  resource_group_name  = azurerm_resource_group.rglab01.name
  virtual_network_name = azurerm_virtual_network.vnetlab01.name
  address_prefixes     = ["10.10.1.0/24"]
}
resource "azurerm_network_security_group" "nsglab01" {
  resource_group_name = azurerm_resource_group.rglab01.name
  location            = var.location
  name                = "vmnsg"
  # INBOUND = traffic coming INTO the VM from outside. Rules are checked lowest priority number first;
  # the first match wins. Anything not allowed here hits Azure's built-in DenyAllInBound (priority 65500).
  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.admin_cidr # only your IP may even try to SSH
    source_port_range          = "*"            # clients pick a random source port, so always "*"
    destination_address_prefix = "*"            # any address in this subnet (only the VM lives here)
    destination_port_range     = "22"
  }
  security_rule {
    name                       = "allow-http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "Internet" # Azure "service tag" = any public internet address
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "80"
  }
  # OUTBOUND: no rules needed. Azure's built-in AllowInternetOutBound (priority 65001) already lets the VM
  # reach the internet (apt install, docker pull). NSGs are stateful: replies to allowed traffic go out automatically.
  tags = local.tags
}
resource "azurerm_subnet_network_security_group_association" "nsgassociation" {
  network_security_group_id = azurerm_network_security_group.nsglab01.id
  subnet_id                 = azurerm_subnet.vmsubnet.id
}
resource "azurerm_public_ip" "vmip" {
  name                = "ipvm"
  sku                 = "Standard"
  allocation_method   = "Static"
  resource_group_name = azurerm_resource_group.rglab01.name
  location            = var.location
  tags                = local.tags
}
