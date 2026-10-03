# Bootstrap (Lab 0 as code)

Sets up a **new Azure account** for the labs. Run it once per account.

| Creates | Why |
|---|---|
| `rg-tfstate` + storage account (versioning, 30-day soft delete, `prevent_destroy`) | Terraform state for every lab |
| Budget `budget-labs`, alerts at 50/80/100% and a 100% forecast | Know before the credit runs out |
| Entra app `gh-oidc-azure-sre-labs` + federated credentials (main, PRs, each deploy environment) | GitHub Actions logs in to Azure with no secret |
| Roles for that identity: Contributor, RBAC Admin **limited to AcrPull/AcrPush**, state blob access | Least privilege: CI can't make itself Owner |
| GitHub repo variables `AZURE_*`, `TFSTATE_*`, and environment `lab01-vm` (needs your approval, `main` only) | Workflows read these |

## Steps (new account)

```bash
az login                                  # pick the NEW subscription in the prompt
az account show --query '{sub:id,tenant:tenantId,user:user.name}'
cp example.tfvars terraform.tfvars        # paste the 3 values + alert email + budget
make check                                # refuses to continue if az is on the wrong account
make providers                            # ~2-5 min the first time
make quota                                # B2s must show no restrictions
make apply                                # read the plan, type yes
make migrate                              # moves this state into the storage account it just made
make env                                  # rewrites ~/.lab0.env (old one is backed up)
gh workflow run whoami && sleep 15 && gh run watch   # must go green on the new subscription
```

Then commit `backend.tf`.

## Chicken and egg

Terraform needs somewhere to store state, but the storage account is what this config creates. So the first
apply uses a local `terraform.tfstate`, and `make migrate` copies it into the new storage account. That's the
standard pattern for bootstrapping a remote state backend.
