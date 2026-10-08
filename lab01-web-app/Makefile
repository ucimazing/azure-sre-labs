# Lab 01: FastAPI + Postgres + Redis behind Nginx, run with Docker Compose.
# Usage: make up, make test, make down. Run `make` or `make help` to list every target.

# Variables. `?=` means "use this unless the caller sets it",
# e.g. make test BASE_URL=http://<vm-ip> later, to test the Azure VM with the same suite.
BASE_URL ?= http://localhost:8088
PYTEST   := ../app/.venv/bin/pytest

# These are command names, not files, so make must always run them.
.PHONY: help up down test logs ps nuke

help:  ## list targets (first target = what plain `make` runs)
	@grep -E '^[a-z.]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-6s %s\n", $$1, $$2}'

# A FILE target: runs only when .env does not exist yet (e.g. a fresh clone).
.env:  ## create .env from .env.example
	cp .env.example .env
	@echo "created .env from .env.example: set a real POSTGRES_PASSWORD in it"

up: .env  ## build images, start everything, wait until healthy
	docker compose up -d --build --wait
	@echo "up: try curl $(BASE_URL)/readyz"

down:  ## stop and remove containers (the database volume is kept)
	docker compose down

test:  ## run the API test suite through nginx
	BASE_URL=$(BASE_URL) $(PYTEST) -q ../app/tests

logs:  ## follow logs of all services (Ctrl+C to stop)
	docker compose logs -f --tail=100

ps:  ## show container status
	docker compose ps

nuke:  ## down AND delete volumes: all data is lost
	docker compose down -v
