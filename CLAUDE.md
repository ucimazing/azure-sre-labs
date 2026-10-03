# azure-sre-labs
Owner: Umesh (DevOps engineer, aiming for Platform/SRE/DevSecOps). MacBook M1, personal pay-as-you-go Azure, GitHub user ucimazing.

## How to work with me
- I want to do the DevOps/SRE work. YOU write all application code, tests and config, and test it before handing it over.
- Guide me in small concrete steps. I procrastinate and may have ADHD: give a tiny "first 15 minutes" action, then the next step.
- At the end of each session, write NEXT.md with what to do next.

## Repo layout
- app/ is the shared FastAPI app (used by several labs)
- labNN-*/ holds each lab's DevOps files (lab01-web-app is done and tested locally, port 8088)
- Lab 0 env vars are in ~/.lab0.env (subscription, tenant, location centralindia, tfstate storage)

## Rules
- One resource group per lab (rg-labNN-...), tags lab=NN owner=ucimazing env=lab
- Always tear down (make down) when done. Never delete rg-tfstate.
- vCPU quota: use Standard_B2s or B1s only (Bsv2 and DSv5 quota is 0)
- Build Docker images on the Azure VM (Mac is arm64, VM is amd64)
- GitHub OIDC (no stored secrets). The subject uses IDs: repo:ucimazing@104823239/<repo>@<repo_id>:ref:refs/heads/main
- Keepalived VRRP does not work on Azure VNets. Use a Standard Load Balancer or unicast.

## Lab status
Done: 0, 1 (local, tested 2026-10-03; Umesh still to run the break-it exercises).
Lab 1 Azure deploys written (lab01-web-app/azure/vm and /appservice), plan-checked, not yet applied.
Next: Lab 6 (Terraform + Ansible), then 10, 2, 3, 11, 12, 7, 8, 9, 4, 5, 13, 14, 15.
