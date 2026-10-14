resource "azurerm_network_security_group" "nsg-appgw" {
  location            = var.location
  name                = "nsg-appgw"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
  security_rule {
    name                       = "allow-gateway-manager"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_address_prefix = "*"
    source_address_prefix      = "GatewayManager"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
  }
  security_rule {
    name                       = "allow-http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_port_range     = "80"
    destination_address_prefix = "*"
    source_port_range          = "*"
    source_address_prefix      = "Internet"
  }
}
resource "azurerm_network_security_group" "nsg-app" {
  location            = var.location
  name                = "nsg-app"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
  security_rule {
    name                       = "allow-appgw-to-app"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_address_prefix = "*"
    source_address_prefix      = "10.20.1.0/24"
    source_port_range          = "*"
    destination_port_range     = "8000"
  }
  security_rule {
    name                       = "deny-vnet-in"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    destination_port_range     = "*"
    destination_address_prefix = "*"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
  }
}
resource "azurerm_network_security_group" "nsg-db" {
  location            = var.location
  name                = "nsg-db"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
  security_rule {
    name                       = "allow-app-to-postgres"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_address_prefix = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "10.20.2.0/24"
    source_port_range          = "*"
  }
  security_rule {
    name                       = "deny-vnet-in"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    destination_port_range     = "*"
    destination_address_prefix = "*"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
  }
}
resource "azurerm_subnet_network_security_group_association" "appgwass" {
  subnet_id                 = azurerm_subnet.appgw.id
  network_security_group_id = azurerm_network_security_group.nsg-appgw.id
}
resource "azurerm_subnet_network_security_group_association" "appass" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.nsg-app.id
}
resource "azurerm_subnet_network_security_group_association" "dbass" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.nsg-db.id
}
