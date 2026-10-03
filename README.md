# Azure SRE Labs

Hands-on DevOps / SRE labs on Azure. Each lab is built, broken on purpose, fixed, and torn down.

Conventions: one resource group per lab (`rg-labNN-...`), tags `lab=NN owner=umesh env=lab`,
and every lab has a Makefile with `up`, `down`, `test`.

| Lab | Topic | Status |
|---|---|---|
| 01 | Web app: CRUD + Postgres + Redis + Nginx + Docker | Not started |
| 02 | HA: 3 app servers + HAProxy + failover | Not started |
| 03 | Database replication | Not started |
| 04 | Kubernetes debugging lab | Not started |
| 05 | CI/CD with rollback | Not started |
| 06 | Terraform + Ansible | Not started |
| 07 | Monitoring: Prometheus + Grafana + Alertmanager | Not started |
| 08 | Central logging: Loki + Alloy | Not started |
| 09 | Load testing | Not started |
| 10 | Reverse proxy + TLS | Not started |
| 11 | Queue + workers | Not started |
| 12 | Backup + restore | Not started |
| 13 | Failure lab | Not started |
| 14 | Cloud cost tracking | Not started |
| 15 | Production capstone (separate repo) | Not started |
