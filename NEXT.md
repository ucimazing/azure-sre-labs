# Where I am (updated 2026-10-21)

Read this file at the start of every session. Update it at the end (or ask Claude to).

## Status

| Lab | Topic | Status |
|---|---|---|
| 0 | Account bootstrap, state storage, GitHub OIDC | ✅ done |
| 1 | Web app: Docker, Compose, Nginx, Terraform VM, Ansible, Key Vault, CI/CD | ✅ done ([recap](docs/lab01-recap.md)) |
| 2 | HA: App Gateway v2 → VM Scale Set across 3 zones → private Postgres | 🔶 **H1–H7 done, H8 in progress** |
| 3–15 | see roadmap below | ⬜ |

## Exact resume point: Lab 2, H8 (CI/CD with your own OIDC environment)

Done: H8 step 0 (H7 merged, #12), step 1 (committed `lab02-ha/terraform/env/lab02.tfvars`, #13).

Next, in order:
1. **Step 2:** federated credential `gh-env-lab02` on the CI identity (subject `repo:ucimazing@104823239/azure-sre-labs@1403235232:environment:lab02`).
2. **Step 3:** GitHub environment `lab02` (you as reviewer, branch policy `main` only).
3. **Step 4:** `lab02-infra.yaml`: plan on PR, apply on `main` after approval. From then on, **Lab 2 is applied only by the pipeline**.
4. **Step 5:** app deploys: image tag in Key Vault + rolling restart one server at a time.
5. **Step 6:** prove it end to end (PR → plan → merge → approve → zero-downtime deploy).
6. **H9:** break-it exercises (kill a server, a zone, bad deploy, DB down), per-server Redis stale-cache lesson, Postgres zone-redundant HA failover session.
7. **H7 tests not yet run:** auto-repair (`docker stop app` on one server) and autoscale (CPU burn, 3 → 4 → 3).

## Cost rules (trial credit ends ~2026-11-03)
- Lab 2 fully up costs about **$0.60/hr** (App Gateway is ~$0.45 of that). It was left running 2026-10-15 → 2026-10-21 (~$85).
- **End of every session:** `cd lab02-ha/terraform && terraform destroy -var-file=env/lab02.tfvars -var-file=terraform.tfvars`
  (or at least the App Gateway: add `-target=azurerm_application_gateway.appgw -target=azurerm_public_ip.appgw`).
- After a full destroy, rebuild with `terraform apply` (~20 min) and re-run the `lab02-image` workflow (the registry is new and empty).
- Check remaining credit: Azure portal → Subscriptions → Azure subscription 1 → Overview.
- Decide before ~2026-11-01: upgrade to pay-as-you-go (keeps free-tier services, removes the spending limit, so set a budget first), or pause the Azure labs.

## Roadmap after Lab 2 (ordered for job-readiness)
1. **Lab 6: multi-environment + branching** (dev/staging/prod from one Terraform, per-environment OIDC identities, trunk-based flow, promote one image).
2. **Lab 4: Kubernetes (AKS)** debugging and deployments: the most-asked skill in Platform/SRE roles.
3. **Labs 7 + 8: monitoring and logging** (Prometheus, Grafana, Alertmanager, Loki): SLOs, alerts, dashboards.
4. **Lab 5: Azure DevOps** pipelines with approvals and rollback (the same ideas as GitHub Actions, in ADO).
5. **Lab 10: HTTPS** for `lab02.umeshdas.dev` (TLS on App Gateway, or Cloudflare). HAProxy lives here too.
6. **Lab 9: load testing** (k6), Lab 12 backup/restore, Lab 13 failure + multi-region DR, Lab 14 cost.

## Open items (not urgent)
- CI RBAC condition (AcrPull, AcrPush, KV Secrets Officer, KV Secrets User) was widened by hand: not in code.
- Lab 1 fixes if it's ever redeployed: Key Vault secret `depends_on` both roles, explicit `ci_object_id`.
- Rename Lab 2's NAT resources (`publicIP` → `pip-nat-lab02`, `NAT-gateway` → `natgw-lab02`).
- Optional: health extension v2.0 (rich states) needs `/healthz` to return `{"ApplicationHealthState": "Healthy"}` (app change).
- `CLAUDE.md` in the repo root is untracked and outdated (centralindia/B2s); PR #6 proposes a version.
