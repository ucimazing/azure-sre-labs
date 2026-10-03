# Terraform state for every lab. The one resource group you never delete.
resource "random_id" "sa" {
  byte_length = 5
}

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-tfstate"
  location = var.location
  tags     = local.permanent_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_account" "tfstate" {
  name                            = "sttfstate${random_id.sa.hex}"
  resource_group_name             = azurerm_resource_group.tfstate.name
  location                        = azurerm_resource_group.tfstate.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.permanent_tags

  blob_properties {
    versioning_enabled = true # every state write keeps the previous version
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# Terraform's backend uses Entra auth (use_azuread_auth), so you need a data-plane role.
resource "azurerm_role_assignment" "me_state" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.me.object_id
}
