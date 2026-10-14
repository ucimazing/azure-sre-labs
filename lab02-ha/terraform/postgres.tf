# Managed PostgreSQL with PRIVATE access only: it gets an IP inside snet-db and has no public endpoint.

# Private "phone book": inside the VNet, the server's name resolves to its private IP.
# The zone name must end in .postgres.database.azure.com for VNet-integrated servers.
resource "azurerm_private_dns_zone" "postgres" {
  name                = "lab02-ha.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# Connect that phone book to our VNet, so machines in the VNet use it.
# (azurerm 5.x: the link takes the zone's ID; 4.x used resource_group_name + private_dns_zone_name.)
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                = "vnet-lab02-link"
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id
  virtual_network_id  = azurerm_virtual_network.vnet.id
  tags                = local.tags
}

# Server names are globally unique.
resource "random_string" "psql" {
  length  = 6
  special = false
  upper   = false
}

# The DB password nobody types. No special characters, so it is safe inside a postgresql:// URL.
resource "random_password" "postgres" {
  length  = 24
  special = false
}

resource "azurerm_postgresql_flexible_server" "db" {
  name                = "psql-lab02-${random_string.psql.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  version             = "16"
  sku_name            = "B_Standard_B1ms" # Burstable, 1 vCPU. Case-sensitive.
  storage_mb          = 32768             # minimum, 32 GB
  zone                = "1"

  backup_retention_days = 7

  # Private access: the server lives in our delegated subnet and is reachable ONLY from inside the VNet.
  delegated_subnet_id           = azurerm_subnet.db.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false

  administrator_login    = "pgadmin"
  administrator_password = random_password.postgres.result

  tags = local.tags

  # The DNS link must exist before the server, and Terraform can't see that dependency itself.
  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]

  lifecycle {
    # Azure may move these during an HA failover (H9). Don't fight it on the next plan.
    ignore_changes = [zone, high_availability[0].standby_availability_zone]
  }
}

# The database the app uses (same name as in Lab 1).
resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "app"
  server_id = azurerm_postgresql_flexible_server.db.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.db.fqdn
}
