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

APP_DIR="${HUB_APP_DIR:-/root/hub}"

echo ""
echo "OpenDriverHub - update / redeploy"
echo ""

cd "$APP_DIR"
git pull --rebase origin "${GIT_DEFAULT_BRANCH:-main}"
echo "Commit: $(git log -1 --pretty='%h %s')"

export COMPOSE_PARALLEL_LIMIT=1

echo ""
echo "Build API image..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" --env-file "$ENV_FILE" build --progress=plain api

echo ""
echo "Build Web image..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" --env-file "$ENV_FILE" build --progress=plain web

docker compose -f "$SCRIPT_DIR/docker-compose.yml" --env-file "$ENV_FILE" up -d
docker compose -f "$SCRIPT_DIR/docker-compose.yml" --env-file "$ENV_FILE" restart nginx

# As migrations do banco são aplicadas automaticamente pela API (EF Core
# code-first) durante o boot — não há passo SQL manual.
echo "Aguardando a API ficar saudável (EF aplica as migrations no boot)..."
for i in $(seq 1 40); do
  if curl -fsS http://localhost/health >/dev/null 2>&1; then
    echo "API OK."
    break
  fi
  sleep 3
done

docker compose -f "$SCRIPT_DIR/docker-compose.yml" --env-file "$ENV_FILE" ps
echo ""
echo "OpenDriverHub updated."
