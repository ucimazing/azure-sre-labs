# Lab 03 notes: database replication

## R1: streaming replication (local, Docker)
- Setup: `local/compose.yaml`. `pg-primary` (Postgres 16) and `pg-replica` (copied with `pg_basebackup`, then streaming WAL).
- The replica connects as the `replicator` role (replication only), allowed by a `host replication` line in `pg_hba.conf`.
- Replication slot `replica1`: the primary keeps WAL until the replica has received it.
  Risk: a replica that stays offline makes WAL pile up on the primary until its disk fills.
- Checks: `pg_stat_replication` shows `streaming | async`. A row written on the primary appears on the replica.
  `pg_is_in_recovery() = t` on the replica, and an INSERT there fails with "read-only transaction".

## R2: async vs sync
| | Async (default) | Sync (`synchronous_standby_names = 'walreceiver'`) |
|---|---|---|
| Insert time, local (both on one machine) | ~2.7 ms | ~1.6 ms |
| Commit returns after | primary wrote WAL | replica confirmed it has the WAL |
| Replica stopped | writes continue | **writes hang** (`wait_event = SyncRep`) |

- Locally the timings are noise. Both containers share one machine, so there's no real network round trip.
  On Azure, sync adds about 1–2 ms per commit across zones and 30–100 ms across regions.
- With the sync replica stopped, `INSERT` hung. Another session could **not** see the row while it waited.
  When the replica came back, the hung INSERT finished by itself within about a second.
- A single sync replica makes write availability worse than no replica: if the replica dies, all writes stop.
  Fixes: `ANY 1 (r1, r2)` with two replicas, or managed HA that handles a failed standby.
- Cancelling a hung sync commit gives a warning that it was already committed locally: the data may exist
  on the primary but not on the replica.

## When to choose which
- **Sync:** data you can never lose once you've told the user "saved" (payments, orders, banking), with replicas in the same region (zones).
- **Async:** read replicas, cross-region disaster recovery, and anything where losing the last second of writes is acceptable in exchange for speed.
- Set back to async (`alter system reset synchronous_standby_names`) for R3 and R4.
