locals {
  permanent_tags = { lab = "00", owner = var.github_owner, env = "permanent" }
}

data "azurerm_client_config" "me" {}

data "azurerm_subscription" "current" {}

resource "terraform_data" "guard" {
  lifecycle {
    precondition {
      condition     = data.azurerm_subscription.current.subscription_id == var.subscription_id
      error_message = "Logged-in subscription is not var.subscription_id. Run: az account set -s <id>"
    }
  }
}
