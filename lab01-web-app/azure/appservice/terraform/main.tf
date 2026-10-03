locals {
  name = "lab01-appsvc"
  tags = { lab = "01", owner = "ucimazing", env = "lab", deploy = "appservice" }
}

# ACR, Postgres and the web app need globally unique names.
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_password" "postgres" {
  length  = 24
  special = false # keeps the DATABASE_URL free of characters that need escaping
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

# ---------- Container registry ----------
resource "azurerm_container_registry" "acr" {
  name                = "acrlab01${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"
  admin_enabled       = false # the web app pulls with its managed identity instead
  tags                = local.tags
}

# ---------- Postgres (managed) ----------
resource "azurerm_postgresql_flexible_server" "db" {
  name                          = "psql-lab01-${random_string.suffix.result}"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  version                       = "16"
  sku_name                      = "B_Standard_B1ms"
  storage_mb                    = 32768
  backup_retention_days         = 7
  administrator_login           = "pgadmin"
  administrator_password        = random_password.postgres.result
  public_network_access_enabled = true
  tags                          = local.tags

  lifecycle {
    ignore_changes = [zone] # Azure picks a zone; don't fight it on every plan
  }
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "app"
  server_id = azurerm_postgresql_flexible_server.db.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# 0.0.0.0-0.0.0.0 is Azure's special "allow Azure services" rule.
# Simple, but it admits traffic from any Azure tenant. Private networking is the upgrade.
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.db.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# ---------- App Service ----------
resource "azurerm_service_plan" "plan" {
  name                = "asp-${local.name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  tags                = local.tags
}

resource "azurerm_linux_web_app" "app" {
  name                = "app-lab01-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true
  tags                = local.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                               = true
    ftps_state                              = "Disabled"
    minimum_tls_version                     = "1.2"
    health_check_path                       = "/healthz"
    health_check_eviction_time_in_min       = 2
    container_registry_use_managed_identity = true

    application_stack {
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
      docker_image_name   = "sre-lab-app:${var.image_tag}"
    }
  }

  logs {
    application_logs {
      file_system_level = "Information" # container stdout, for `make logs`
    }
    http_logs {
      file_system {
        retention_in_days = 3
        retention_in_mb   = 35
      }
    }
  }

  app_settings = {
    WEBSITES_PORT = "8000"
    DATABASE_URL  = "postgresql://pgadmin:${random_password.postgres.result}@${azurerm_postgresql_flexible_server.db.fqdn}:5432/app?sslmode=require"
    # No REDIS_URL: the app runs without a cache here. See README for why.
  }
}

resource "azurerm_role_assignment" "web_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}
