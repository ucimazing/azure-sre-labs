terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  # Filled in by `make init` from ~/.lab0.env (partial backend config).
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  # Providers were registered in Lab 0; don't let Terraform register extra ones.
  resource_provider_registrations = "none"
}
