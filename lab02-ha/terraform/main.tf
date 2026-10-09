locals  {
  tags = { lab = "02", owner = "ucimazing", env = "lab" }
}
resource "azurerm_resource_group" "rg" {
  location = var.location
  name     = "rg-lab02-ha"

}
resource "azurerm_virtual_network" "vnet" {
  name = "vnet-lab02"
  location = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space = ["10.20.0.0/16"]
}
resource "azurerm_subnet" "edge" {
  name = "snet-appgw"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = ["10.20.1.0/24"]
}
resource "azurerm_subnet" "app" {
  name = "snet-app"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = ["10.20.2.0/24"]
}
resource "azurerm_subnet" "db" {
  name = "snet-db"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = ["10.20.3.0/24"]
  delegation {
    name = "postgres"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}
