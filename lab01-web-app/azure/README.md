# Lab 01 on Azure: two ways to deploy the same app

The same app (`../../app`) deployed two different ways, so you can feel the trade-off between them.

| | `vm/` (IaaS) | `appservice/` (PaaS) |
|---|---|---|
| Resource group | `rg-lab01-vm` | `rg-lab01-appsvc` |
| Tools | Terraform + Ansible + Docker Compose | Terraform + ACR Tasks + App Service |
| You manage | OS, patches, Docker, Postgres, Redis, Nginx, backups | only the container image and settings |
| Postgres | container on the VM (data dies with the VM disk) | Azure Database for PostgreSQL Flexible Server (managed, 7-day backups) |
| Redis | container on the VM | **none** (app runs without the cache; see "Things to notice") |
| Image built | on the VM (amd64) | in Azure by `az acr build` (amd64), so the Mac's arm64 doesn't matter |
| TLS | none (plain HTTP on :80, Lab 10 fixes this) | free HTTPS on `*.azurewebsites.net` |
| Cost if left running* | ~$0.05/hr (~$37/month) | ~$0.05/hr (~$36/month) |

\* Central India retail prices, Oct 2026: B2s $0.0448/hr + static IP $0.005/hr; App Service B1 Linux $0.018/hr + Postgres B1ms $0.0245/hr + storage + ACR Basic $0.17/day. **Run `make down` when you finish.** Either one costs a few cents per session.

Terraform state goes to `rg-tfstate` (keys `lab01-vm.tfstate`, `lab01-appservice.tfstate`), authenticated with your Entra login (no storage keys).

## Path A: plain VM

```bash
cd lab01-web-app/azure/vm
make plan     # read-only: shows the 8 resources it will create
make up       # terraform apply (type yes) -> ansible -> smoke test
make ssh      # look around: docker ps, docker compose logs, df -h
make down     # destroy (type yes)
```

What happens:
1. **Terraform** creates the RG, VNet/subnet, a network security group (SSH only from *your* IP, HTTP from anywhere), a static public IP and an Ubuntu 24.04 B2s VM that logs in with your `~/.ssh/id_ed25519` key.
2. `make release` runs `git archive` on the **committed** code into a tarball. Uncommitted edits are *not* deployed, on purpose: what runs is what's in git.
3. **Ansible** waits for cloud-init, installs Docker from Docker's apt repo, unpacks the release, writes `.env` (the Postgres password is generated once into `ansible/secrets/`, gitignored), runs `docker compose up --build --wait`, then checks `/readyz` from the VM.
4. `smoke.sh` runs against `http://<public-ip>`.

Run `make deploy` again after changing code: Ansible is safe to re-run (idempotent).

## Path B: App Service (Web App for Containers)

```bash
cd lab01-web-app/azure/appservice
make plan     # read-only: shows the 10 resources
make up       # terraform apply (type yes, Postgres takes 5-10 min) -> az acr build -> restart -> smoke test
make logs     # stream container stdout
make down
```

What happens:
1. **Terraform** creates: ACR (Basic, admin user *disabled*), Postgres Flexible Server + `app` database + firewall rule, a Linux B1 App Service plan, and the web app with a **system-assigned managed identity** that has `AcrPull` on the registry. No registry password exists anywhere.
2. The web app is configured for the image `sre-lab-app:<git short SHA>`. That tag doesn't exist yet on the first apply, so the app fails to start for a moment. That's expected.
3. `az acr build` uploads `app/` and builds it **in Azure**, then pushes that tag.
4. `az webapp restart` makes App Service pull the image. `make test` runs the smoke test over HTTPS.

Ship a new version: commit, then `make apply image restart` (the new SHA becomes the new tag, so every deploy is traceable to a commit).

## Things to notice (the learning part)

1. **Where does the data live?** On the VM, Postgres lives in a Docker volume on the VM disk, and `make down` deletes it. On App Service it's a managed server with point-in-time restore. Which would you trust in prod?
2. **Redis is missing on App Service.** App Service runs *one* container per app. Your choices: the managed Redis service (extra cost), a sidecar container, or skip the cache. The app was built to degrade gracefully, so it still works. `/readyz` just doesn't list redis.
3. **Who patches the OS?** VM: you (try `sudo apt list --upgradable` over `make ssh`). App Service: Microsoft.
4. **Health checks.** App Service pings `/healthz` and replaces the instance if it fails for 2 minutes. On the VM, Docker restarts a dead container, but nobody replaces a dead VM (Lab 2 fixes that).
5. **Secrets.** The DB password ends up in Terraform state (encrypted blob, RBAC-protected) and in an app setting. Industry upgrade: Key Vault references, or passwordless Entra auth to Postgres via the managed identity.
6. **Network exposure.** Postgres allows "Azure services", i.e. any Azure tenant can reach the port (still password-protected). Upgrade: VNet integration + private endpoint.

## Other ways to run this app on Azure (besides AKS)

| Option | Merits | Demerits | Good lab for |
|---|---|---|---|
| **VM + Docker Compose** (`vm/`) | Full control; cheapest to understand; same as your laptop | You own patching, backups, HA, TLS; single point of failure | Linux, Ansible, debugging |
| **VM Scale Set + Load Balancer** | Autoscaling and self-healing VMs; rolling upgrades | Need a golden image or cloud-init; stateful parts must move off the VMs | Lab 2 (HA) |
| **App Service** (`appservice/`) | Fastest to production; HTTPS, scaling, slots, auth built in; no OS to patch | One container per app; less control; Basic plan has no deployment slots (Standard does) | PaaS, blue/green with slots |
| **Azure Container Apps** | Serverless containers on managed Kubernetes; scale to zero; KEDA autoscaling (great for Lab 11 workers); multiple containers and sidecars; revisions with traffic splitting | No kubectl access; fewer knobs than AKS; Kubernetes concepts in a different form | **Strongly recommended 3rd way**: closest to modern prod, without AKS's cost |
| **Azure Container Instances** | One command to run a container group; per-second billing; good for jobs | No autoscaling, no rolling deploys, weak for long-running web apps | One-off jobs, the Lab 12 backup runner |
| **k3s / kubeadm on VMs** | Real Kubernetes you build yourself; learn the control plane, etcd, CNI | You operate the cluster (upgrades, certs); not what most companies run on Azure | Deep Kubernetes understanding before Lab 4 |
| **Azure Functions** | Pay per execution; event-driven | Would need rewriting into functions; cold starts | Not a fit for this app; fine for small glue code |

Suggested order: **VM → App Service → Container Apps → AKS**. Each step hands one more layer (OS, then runtime, then orchestration) to Azure.
