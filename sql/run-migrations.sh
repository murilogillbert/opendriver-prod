#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

set -a
source "$ENV_FILE"
set +a

SQL_CONTAINER="${SQL_CONTAINER:-opendriver-sqlserver}"
DATABASE="${SQLSERVER_DATABASE:-OpenDriver}"
PASSWORD="${SQLSERVER_PASSWORD:?SQLSERVER_PASSWORD is required}"
MIGRATIONS_DIR="${OPEN_DRIVER_APP_DIR:-/root/opendriver}/sql/migrations"
SQLCMD='SQLCMD=/opt/mssql-tools18/bin/sqlcmd; [ -x "$SQLCMD" ] || SQLCMD=/opt/mssql-tools/bin/sqlcmd; "$SQLCMD"'

echo "Waiting for SQL Server..."
for i in $(seq 1 60); do
  if docker exec -e SA_PASSWORD="$PASSWORD" "$SQL_CONTAINER" sh -lc "$SQLCMD -S localhost -U sa -P \"\$SA_PASSWORD\" -C -Q 'SELECT 1'" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

docker exec -e SA_PASSWORD="$PASSWORD" "$SQL_CONTAINER" sh -lc "$SQLCMD -S localhost -U sa -P \"\$SA_PASSWORD\" -C -Q \"IF DB_ID(N'$DATABASE') IS NULL CREATE DATABASE [$DATABASE];\""

for migration in "$MIGRATIONS_DIR"/*.sql; do
  name="$(basename "$migration")"
  applied="$(docker exec -e SA_PASSWORD="$PASSWORD" "$SQL_CONTAINER" sh -lc "$SQLCMD -S localhost -U sa -P \"\$SA_PASSWORD\" -C -d '$DATABASE' -h -1 -W -Q \"SET NOCOUNT ON; IF OBJECT_ID(N'dbo.schema_migrations', N'U') IS NULL SELECT 0 ELSE SELECT COUNT(1) FROM dbo.schema_migrations WHERE migration_name = N'$name';\"" | tr -d '\r[:space:]')"

  if [ "$applied" = "1" ]; then
    echo "Skipping $name"
    continue
  fi

  echo "Applying $name"
  docker cp "$migration" "$SQL_CONTAINER:/tmp/$name"
  docker exec \
    -e SA_PASSWORD="$PASSWORD" \
    -e MIGRATION_NAME="$name" \
    "$SQL_CONTAINER" \
    sh -lc "$SQLCMD -S localhost -U sa -P \"\$SA_PASSWORD\" -C -d '$DATABASE' -i '/tmp/$name' -b"
done

echo "Migrations completed."
