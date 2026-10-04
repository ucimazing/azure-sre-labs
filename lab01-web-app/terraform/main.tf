resource "azurerm_resource_group" "rglab01" {
  location = var.location
  tags     = { lab = "01", owner = "ucimazing", env = "lab" }
  name     = "rg-lab01-vm"
}
