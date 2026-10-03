# Lab 01: FastAPI + Postgres + Redis behind Nginx, all in Docker Compose (runs locally).
SHELL := /bin/bash
COMPOSE := docker compose
PORT ?= $(shell grep -s '^HTTP_PORT=' .env | cut -d= -f2 || echo 8088)
BASE_URL ?= http://localhost:$(or $(PORT),8088)
VENV := ../app/.venv

.PHONY: up down test smoke pytest ps logs psql redis-cli nuke

.env:
	cp .env.example .env

up: .env  ## build and start the stack, wait until healthy
	$(COMPOSE) up -d --build --wait
	@echo "up: $(BASE_URL)  (try: curl $(BASE_URL)/readyz)"

down:  ## stop and remove containers (keeps the Postgres volume)
	$(COMPOSE) down

nuke:  ## down + delete the Postgres volume
	$(COMPOSE) down -v

test: smoke pytest  ## smoke test with curl, then the pytest suite

smoke:
	BASE_URL=$(BASE_URL) ./smoke.sh

pytest: $(VENV)/bin/pytest
	BASE_URL=$(BASE_URL) $(VENV)/bin/pytest -q ../app/tests

$(VENV)/bin/pytest:
	test -d $(VENV) || python3 -m venv $(VENV)
	$(VENV)/bin/pip install -q -r ../app/requirements-dev.txt

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f --tail=100

psql:
	$(COMPOSE) exec postgres sh -c 'psql -U $$POSTGRES_USER -d $$POSTGRES_DB'

redis-cli:
	$(COMPOSE) exec redis redis-cli
