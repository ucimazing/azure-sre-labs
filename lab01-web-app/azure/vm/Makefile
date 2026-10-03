# Lab 01 on a plain VM: Terraform builds the VM, Ansible installs Docker and runs compose.
SHELL := /bin/bash
include $(HOME)/.lab0.env

REPO   := $(shell git rev-parse --show-toplevel)
TF     := terraform -chdir=terraform
MY_IP  := $(shell curl -s -4 ifconfig.me)
IP      = $(shell $(TF) output -raw public_ip 2>/dev/null)

.PHONY: init plan up apply deploy test ssh down release

init:
	$(TF) init -reconfigure \
	  -backend-config="resource_group_name=$(STATE_RG)" \
	  -backend-config="storage_account_name=$(STATE_SA)" \
	  -backend-config="container_name=$(STATE_CONTAINER)" \
	  -backend-config="key=lab01-vm.tfstate" \
	  -backend-config="use_azuread_auth=true"

plan: init
	$(TF) plan -var admin_cidr=$(MY_IP)/32

up: apply deploy test  ## everything: infra, config, smoke test

apply: init  ## shows the plan and asks you to type yes
	$(TF) apply -var admin_cidr=$(MY_IP)/32

release:  ## package the committed code (what you deploy is what's in git)
	mkdir -p build
	git -C $(REPO) archive --format=tar.gz -o $(CURDIR)/build/release.tgz HEAD app lab01-web-app

deploy: release
	printf '[app]\n%s ansible_user=azureuser\n' "$(IP)" > ansible/inventory.ini
	cd ansible && ansible-playbook playbook.yml

test:
	BASE_URL=http://$(IP) ../../smoke.sh

ssh:
	ssh azureuser@$(IP)

down:  ## destroy everything in rg-lab01-vm
	$(TF) destroy -var admin_cidr=$(MY_IP)/32
