#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing .env. Copy .env.example to .env and adjust secrets."
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

APP_DIR="${OPEN_DRIVER_APP_DIR:-/root/opendriver}"

echo ""
echo "Open Driver - update / redeploy"
echo ""

cd "$APP_DIR"
git pull --rebase origin main
echo "Commit: $(git log -1 --pretty='%h %s')"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" --env-file "$ENV_FILE" build
docker compose -f "$SCRIPT_DIR/docker-compose.yml" --env-file "$ENV_FILE" up -d

bash "$SCRIPT_DIR/sql/run-migrations.sh"

docker compose -f "$SCRIPT_DIR/docker-compose.yml" --env-file "$ENV_FILE" ps
echo ""
echo "Open Driver updated."
