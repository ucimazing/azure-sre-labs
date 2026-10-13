resource "azurerm_nat_gateway" "nat" {
  location                = var.location
  name                    = "NAT-gateway"
  resource_group_name     = azurerm_resource_group.rg.name
  tags                    = local.tags
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
}
resource "azurerm_public_ip" "ip" {
  location            = var.location
  name                = "publicIP"
  tags                = local.tags
  sku                 = "Standard"
  allocation_method   = "Static"
  resource_group_name = azurerm_resource_group.rg.name
}
resource "azurerm_nat_gateway_public_ip_association" "natass" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.ip.id
}
resource "azurerm_subnet_nat_gateway_association" "natsubass" {
  nat_gateway_id = azurerm_nat_gateway.nat.id
  subnet_id      = azurerm_subnet.app.id
}
