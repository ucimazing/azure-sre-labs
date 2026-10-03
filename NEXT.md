# Next steps (updated 2026-10-04)

## Done 2026-10-04: new Azure account bootstrapped
- Region southindia (centralindia blocks B-series for this trial). State: sttfstate557486d7ce / tfstate.
- GitHub OIDC verified (whoami green on subscription b38d2634...). ~/.lab0.env rewritten.
- Next: build Lab 1 VM CI/CD (GitHub Actions + ACR + ansible-pull). Pick VM size: B2ats_v2 or B2as_v2.

## New: Lab 1 on Azure (two ways)
Written and checked with `terraform validate` + `terraform plan` (nothing applied yet). See `lab01-web-app/azure/README.md`.
1. `cd lab01-web-app/azure/vm && make up`, look around with `make ssh`, then `make down`.
2. `cd ../appservice && make up`, `make logs`, then `make down`.
3. Answer the 6 "Things to notice" questions in that README in your own words.
4. Optional 3rd way: Azure Container Apps (ask Claude: "add Container Apps for lab01").

## Where things are
- Lab 1 is built and tested (`make up && make test` passes: smoke + 4 pytest tests). Stack is torn down.
- Lab 1 runs on **port 8088** (something else on the Mac owns 8080).

## First 15 minutes (do just this)
1. `cd lab01-web-app && make up && make test`. Watch it go green.
2. Do break-it exercise **#1 only** from `lab01-web-app/README.md` (stop Redis). Write one sentence on why the app stayed up.
3. `make down`. Done for the session if that's all you have energy for.

## After that
- Finish break-it #2 to #5 in the Lab 1 README. #2 (liveness vs readiness) is the one interviewers ask about.
- Then start **Lab 6 (Terraform + Ansible)**. Plan, so you know what's coming:
  - Terraform: `rg-lab06-tfansible`, VNet + NSG (22 from your IP only, 80), one `Standard_B2s` Ubuntu VM, remote state in `rg-tfstate`.
  - Ansible: install Docker on the VM, copy `app/` + `lab01-web-app/`, `make up` there (image builds on the amd64 VM, per the rules).
  - Makefile: `up` (terraform apply + ansible), `test` (smoke.sh against the VM's public IP), `down` (terraform destroy).
  - Ask Claude: "start Lab 6" and it will write the Terraform/Ansible and test the plan.
