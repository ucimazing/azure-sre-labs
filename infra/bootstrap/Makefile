# Lab 0 bootstrap as code: state storage, budget, GitHub OIDC identity, repo variables.
# Run once per Azure account. Order: make check -> make providers -> make apply -> make migrate -> make env
SHELL := /bin/bash
TFVARS := terraform.tfvars
var = $(shell sed -nE 's/^$(1)[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' $(TFVARS))
export GITHUB_TOKEN := $(shell gh auth token 2>/dev/null)
# Use your `az login`, never a service principal left over in the shell, and the tfvars tenant/sub.
unexport ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_CLIENT_CERTIFICATE_PATH ARM_USE_OIDC ARM_USE_MSI
export ARM_TENANT_ID       := $(call var,tenant_id)
export ARM_SUBSCRIPTION_ID := $(call var,subscription_id)
ENV_FILE := $(HOME)/.lab0.env

.PHONY: check providers init plan apply migrate env quota

check:  ## refuse to run unless the az CLI is on the NEW account
	@test -f $(TFVARS) || { echo "copy example.tfvars to $(TFVARS) and fill it in"; exit 1; }
	@test -n "$$GITHUB_TOKEN" || { echo "run: gh auth login"; exit 1; }
	@user=$$(az account show --query user.name -o tsv); sub=$$(az account show --query id -o tsv); \
	 echo "az user: $$user   subscription: $$sub"; \
	 [[ "$$user" == "$(call var,expected_user)" ]] || { echo "WRONG ACCOUNT (expected $(call var,expected_user)). Run: az login"; exit 1; }; \
	 [[ "$$sub" == "$(call var,subscription_id)" ]] || { echo "WRONG SUBSCRIPTION. Run: az account set -s $(call var,subscription_id)"; exit 1; }; \
	 echo "ok: right account"

providers: check  ## register the Azure resource providers the labs use (idempotent)
	for p in Microsoft.Compute Microsoft.Network Microsoft.Storage Microsoft.ContainerRegistry \
	         Microsoft.ManagedIdentity Microsoft.Authorization Microsoft.Consumption Microsoft.Insights \
	         Microsoft.OperationalInsights Microsoft.KeyVault Microsoft.DBforPostgreSQL Microsoft.Web \
	         Microsoft.ContainerService Microsoft.App Microsoft.ServiceBus; do \
	  az provider register -n $$p --wait -o none && echo "registered $$p"; done

init:
	@if [[ -f backend.tf ]]; then source $(ENV_FILE) && terraform init -reconfigure \
	  -backend-config="resource_group_name=$$STATE_RG" -backend-config="storage_account_name=$$STATE_SA" \
	  -backend-config="container_name=$$STATE_CONTAINER" -backend-config="key=bootstrap.tfstate" \
	  -backend-config="use_azuread_auth=true"; \
	else terraform init; fi

plan: check init
	terraform plan -var-file=$(TFVARS)

apply: check init  ## shows the plan, asks you to type yes
	terraform apply -var-file=$(TFVARS)

migrate: check  ## move local state into the storage account it just created (one time)
	@test ! -f backend.tf || { echo "already migrated"; exit 1; }
	@# read outputs BEFORE backend.tf exists, otherwise terraform asks for init and returns nothing
	rg=$$(terraform output -raw state_rg) && sa=$$(terraform output -raw state_sa) && ct=$$(terraform output -raw state_container) && \
	test -n "$$sa" && \
	printf 'terraform {\n  backend "azurerm" {}\n}\n' > backend.tf && \
	terraform init -migrate-state -force-copy \
	  -backend-config="resource_group_name=$$rg" -backend-config="storage_account_name=$$sa" \
	  -backend-config="container_name=$$ct" -backend-config="key=bootstrap.tfstate" \
	  -backend-config="use_azuread_auth=true" || { rm -f backend.tf; exit 1; }
	rm -f terraform.tfstate terraform.tfstate.backup
	@echo "migrated. Commit backend.tf."

env:  ## write ~/.lab0.env (the Makefiles in every lab read it); keeps a backup of the old one
	@test ! -f $(ENV_FILE) || cp $(ENV_FILE) $(ENV_FILE).bak-$$(date +%Y%m%d-%H%M%S)
	@printf '%s\n' "# written by infra/bootstrap (make env)" \
	  "export ARM_SUBSCRIPTION_ID=$(call var,subscription_id)" \
	  "export ARM_TENANT_ID=$(call var,tenant_id)" \
	  "export LAB_LOCATION=$(call var,location)" \
	  "export STATE_RG=$$(terraform output -raw state_rg)" \
	  "export STATE_SA=$$(terraform output -raw state_sa)" \
	  "export STATE_CONTAINER=$$(terraform output -raw state_container)" \
	  "export GH_USER=ucimazing" > $(ENV_FILE)
	@cat $(ENV_FILE)

quota:  ## vCPU quota and whether B2s is offered to this subscription in centralindia
	az vm list-usage -l centralindia -o table | grep -E 'Name|Total Regional|Standard BS Family'
	az vm list-skus -l centralindia --size Standard_B2s --query "[].{sku:name,restrictions:restrictions[].reasonCode}" -o table
