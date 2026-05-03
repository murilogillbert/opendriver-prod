#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo bash bootstrap-ubuntu.sh"
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
  echo "Created $ENV_FILE"
  echo "Edit secrets and repository values, then run this script again."
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

APP_DIR="${OPEN_DRIVER_APP_DIR:-/root/opendriver}"
REPO_URL="${OPEN_DRIVER_REPO_URL:?OPEN_DRIVER_REPO_URL is required}"
GIT_NAME="${GIT_USER_NAME:-Open Driver Deploy}"
GIT_EMAIL="${GIT_USER_EMAIL:-deploy@opendriver.com.br}"
GIT_BRANCH="${GIT_DEFAULT_BRANCH:-main}"

echo ""
echo "Open Driver - Ubuntu bootstrap"
echo ""

apt-get update -qq
apt-get install -y -qq \
  ca-certificates curl git gnupg lsb-release ufw fail2ban nano unzip jq

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

systemctl enable --now docker >/dev/null

if ! command -v cloudflared >/dev/null 2>&1; then
  install -d -m 0755 /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
    | gpg --dearmor -o /usr/share/keyrings/cloudflare-main.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/cloudflared.list
  apt-get update -qq
  apt-get install -y -qq cloudflared
fi

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch "$GIT_BRANCH"
git config --global pull.rebase true
git config --global credential.helper store
git config --global --add safe.directory "$APP_DIR"
git config --global --add safe.directory "$SCRIPT_DIR"

ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow 22/tcp >/dev/null
ufw --force enable >/dev/null
systemctl enable --now fail2ban >/dev/null

if ! grep -q "Open Driver production helpers" /root/.bashrc; then
  {
    echo ""
    cat "$SCRIPT_DIR/bashrc.opendriver"
  } >> /root/.bashrc
fi

if [ -d "$APP_DIR/.git" ]; then
  git -C "$APP_DIR" fetch origin "$GIT_BRANCH"
  git -C "$APP_DIR" checkout "$GIT_BRANCH"
  git -C "$APP_DIR" pull --rebase origin "$GIT_BRANCH"
else
  git clone --branch "$GIT_BRANCH" "$REPO_URL" "$APP_DIR"
fi

bash "$SCRIPT_DIR/update.sh"

echo ""
echo "Bootstrap complete."
echo "Next: bash cloudflare-tunnel-init.sh"
