# Next steps (updated 2026-10-08)

## Where things are
- You decided to write the DevOps files yourself. So the Dockerfile, compose, nginx, Terraform, Ansible and CI were removed from the repo (commit 8f3fab3).
  The app (`app/main.py` + `app/tests/`) is still here.
- The Azure bootstrap from Lab 0 is **still live in Azure**: rg-tfstate, storage account sttfstate557486d7ce, the GitHub OIDC app, and the repo variables.
  Its Terraform code is gone from the working tree but still in git history: `git show 3aacacf:infra/bootstrap/state.tf`.
- Trial credit runs out around **2026-11-03**. Region southindia, 4 vCPUs.

## First 15 minutes (do just this)
Write `app/Dockerfile` yourself and get the app running in a container on your Mac.
1. `cd app && cat requirements.txt main.py | head -40` to see what the app needs.
2. Write a Dockerfile: `python:3.12-slim`, install requirements, run `uvicorn main:app --host 0.0.0.0 --port 8000`, run as a non-root user.
3. `docker build -t lab01-app . && docker run --rm -p 8088:8000 lab01-app`, then in a second terminal: `curl localhost:8088/healthz`.
   `/healthz` should return OK. `/readyz` should FAIL because there's no Postgres yet. That's correct; write one sentence on why.
4. Commit it. Stop here if you're out of energy.

Stuck? Ask Claude to "review my Dockerfile", or peek at the old one: `git show b3770ec:app/Dockerfile`.

## After that (one per session)
1. `lab01-web-app/docker-compose.yml`: app + postgres + redis + nginx on port 8088. Done when `pytest app/tests` passes against it.
2. Break-it exercises (ask Claude for the list again). #2, liveness vs readiness, is the one interviewers ask about.
3. Restore `infra/bootstrap/` yourself (copy it back from history if you like, but read every file), then run `terraform plan`. It should show **no changes**, because state is remote.
4. Lab 1 VM on Azure: Terraform (VNet, NSG 22 from your IP only, B2ats_v2) → Ansible → GitHub Actions. Always `terraform destroy` at the end.

## Loose ends
- Delete the old client secret in the OLD tenant's Entra ID (security hygiene).
