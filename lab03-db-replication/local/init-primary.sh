#!/bin/bash
# Runs once when the primary is first created: a login just for replication, allowed in pg_hba.conf.
set -euo pipefail
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD '$REPL_PASSWORD';"
echo "host replication replicator all scram-sha-256" >> "$PGDATA/pg_hba.conf"
