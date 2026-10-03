terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
  # First apply uses local state (the storage account doesn't exist yet).
  # `make migrate` then writes backend.tf and moves this state into it.
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  # `make providers` registers what the labs need, explicitly and once.
  resource_provider_registrations = "none"
}

provider "azuread" {
  tenant_id = var.tenant_id
}

# Token comes from GITHUB_TOKEN (the Makefile sets it from `gh auth token`).
provider "github" {
  owner = var.github_owner
}
