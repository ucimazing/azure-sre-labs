# Next steps (updated 2026-10-08)

Lab 1 is complete end to end. The full recap is in [docs/lab01-recap.md](docs/lab01-recap.md).

## First 15 minutes next session
1. If the VM is still up and you're not using it: `terraform -chdir=lab01-web-app/terraform destroy` (about $0.11/hr).
2. Read section 5 of the recap (edge cases) and pick one ❌ to fix. The smallest is the app healthcheck (runbook #0).

## Then, in order
- **Lab 9, load testing**: start with L1, a k6 smoke test against the Lab 1 VM. Then a stress test to find the breaking point (predicted bottlenecks: one uvicorn worker, a DB pool of 10, B-series CPU credits).
- **Lab 10, `lab01.umeshdas.dev` with HTTPS**: decide **A** (Cloudflare proxy + Origin CA cert, recommended) or **B** (Let's Encrypt on the VM). Don't touch the root `umeshdas.dev`, which is already live.
- **Lab 6, multi-environment**: dev, staging and prod from the same Terraform, trunk-based branching, GitHub Environments with approvals, build once and promote the same image.

## Reminders
- The trial credit ends around **2026-11-03**.
- The CI identity's RBAC condition was widened by hand (AcrPull, AcrPush, Key Vault Secrets Officer, Key Vault Secrets User). It's not in code.
- `CLAUDE.md` still says centralindia / B2s. Update it.
