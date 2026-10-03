# Lab 01 on App Service: managed Postgres + ACR + Linux Web App for Containers.
SHELL := /bin/bash
include $(HOME)/.lab0.env

REPO := $(shell git rev-parse --show-toplevel)
TAG  := $(shell git rev-parse --short HEAD)
TF   := terraform -chdir=terraform
out   = $(shell $(TF) output -raw $(1) 2>/dev/null)

.PHONY: init plan up apply image restart test logs down

init:
	$(TF) init -reconfigure \
	  -backend-config="resource_group_name=$(STATE_RG)" \
	  -backend-config="storage_account_name=$(STATE_SA)" \
	  -backend-config="container_name=$(STATE_CONTAINER)" \
	  -backend-config="key=lab01-appservice.tfstate" \
	  -backend-config="use_azuread_auth=true"

plan: init
	$(TF) plan -var image_tag=$(TAG)

up: apply image restart test  ## everything: infra, image, smoke test

apply: init  ## shows the plan and asks you to type yes (Postgres takes ~5-10 min)
	$(TF) apply -var image_tag=$(TAG)

image:  ## build in Azure (ACR Tasks, amd64): no local Docker, no arm64 problem
	az acr build -r $(call out,acr_name) -t sre-lab-app:$(TAG) $(REPO)/app

restart:  ## make the web app pull the image it is configured for
	az webapp restart -g $(call out,resource_group) -n $(call out,webapp_name)
	@echo "waiting for the container to come up..."
	@for i in $$(seq 1 40); do curl -fs $(call out,url)/healthz >/dev/null && echo up && exit 0; sleep 6; done; echo "not up yet: try 'make logs'"; exit 1

test:
	BASE_URL=$(call out,url) EXPECT_NGINX=0 EXPECT_REDIS=0 ../../smoke.sh

logs:
	az webapp log tail -g $(call out,resource_group) -n $(call out,webapp_name)

down:  ## destroy everything in rg-lab01-appsvc
	$(TF) destroy -var image_tag=$(TAG)
