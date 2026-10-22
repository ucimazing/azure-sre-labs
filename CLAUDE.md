# azure-sre-labs
Owner: Umesh (DevOps engineer, aiming for Platform/SRE/DevSecOps). MacBook M1, personal pay-as-you-go Azure, GitHub user ucimazing.

## How to work with me
- I want to do the DevOps/SRE work. YOU write application code (app/) and its tests, and test them before handing over.
- I write the DevOps files myself (Dockerfile, compose, nginx, Terraform, Ansible, CI). You review them, explain, and give hints; don't write them for me unless I ask. Earlier Claude-written versions are in git history (e.g. `git show 6faeed5:infra/bootstrap/main.tf`) if I get stuck.
- Guide me in small concrete steps. I procrastinate and may have ADHD: give a tiny "first 15 minutes" action, then the next step.
- At the end of each session, write NEXT.md with what to do next.

## Repo layout
- app/ is the shared FastAPI app (used by several labs)
- labNN-*/ holds each lab's DevOps files (lab01-web-app: compose on port 8088, terraform/, ansible/, deploy/, RUNBOOK.md)
- docs/lab01-recap.md: what Lab 1 built, challenges, edge cases
- Lab 0 env vars are in ~/.lab0.env (subscription, tenant, location southindia, tfstate storage)
- Lab 0 bootstrap is applied in Azure, but its Terraform is not in the tree any more (history: `git show 3aacacf:infra/bootstrap/identity.tf`)

## Azure account (switched 2026-10-04)
- NEW: free trial, $200 credit valid 30 days (until ~2026-11-03), spending limit on. Login = the account's own email (never commit it).
- OLD pay-as-you-go account (revointeriorofficial@...) is no longer used for labs. ~/.lab0.env backups (.bak-*) point at it.
- Free trial: ACR Tasks (az acr build) may be blocked, so build images in CI. Check quota with `az vm list-usage -l southindia -o table`.

## Rules
- One resource group per lab (rg-labNN-...), tags lab=NN owner=ucimazing env=lab
- Always tear down (make down) when done. Never delete rg-tfstate.
- REGION = southindia (new trial). In centralindia this trial blocks every B-series and most D sizes (NotAvailableForSubscription).
- Trial quota: 4 vCPUs per region. In southindia: B2s/B1s v1 blocked; allowed: B2ats_v2 (2 vCPU/1 GB, ~$0.013/hr, free-tier eligible), B2as_v2/B2s_v2 (2 vCPU/8 GB, ~$0.11/hr), D2s_v5 etc.
- Build Docker images on the Azure VM (Mac is arm64, VM is amd64)
- GitHub OIDC (no stored secrets). The CI identity's conditional RBAC admin was widened BY HAND to AcrPull, AcrPush, Key Vault Secrets Officer/User (not in code yet). The subject uses IDs: repo:ucimazing@104823239/<repo>@<repo_id>:ref:refs/heads/main
- Keepalived VRRP does not work on Azure VNets. Use a Standard Load Balancer or unicast.

## CI/CD split (learn both)
- GitHub Actions: Lab 1 VM, 6, 10, 2, 3
- Azure DevOps: Lab 1 App Service, 5, 7, 8, 9
- Lab 1 VM CD design: CI builds the image (amd64 runner) and pushes to ACR, the VM pulls with its managed identity,
  deploy = `az vm run-command` running ansible-pull on the VM (no SSH from CI, no stored SSH key)

## Lab status
Done: 0, 1 (end to end on Azure by 2026-10-08: VM + Key Vault + ACR, GitHub Actions CI, infra plan/apply, run-command + ansible-pull deploy).
Next (see NEXT.md): Lab 9 load test, Lab 10 HTTPS on lab01.umeshdas.dev, Lab 6 multi-environment; then 2, 3, 11, 12, 7, 8, 4, 5, 13, 14, 15.
