#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo bash cloudflare-tunnel-init.sh"
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing .env. Copy .env.example to .env first."
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

TUNNEL_NAME="${CLOUDFLARE_TUNNEL_NAME:-opendriver}"
TUNNEL_ID="${CLOUDFLARE_TUNNEL_ID:-}"
DOMAIN="${OPEN_DRIVER_DOMAIN:-opendriver.com.br}"
WWW_DOMAIN="${OPEN_DRIVER_WWW_DOMAIN:-www.opendriver.com.br}"

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "cloudflared is not installed. Run bootstrap-ubuntu.sh first."
  exit 1
fi

if [ ! -f /root/.cloudflared/cert.pem ]; then
  echo "Cloudflare login is required. Authorize the URL that opens in the terminal."
  cloudflared tunnel login
fi

if [ -z "$TUNNEL_ID" ]; then
  if cloudflared tunnel info "$TUNNEL_NAME" >/tmp/opendriver-tunnel-info.txt 2>/dev/null; then
    TUNNEL_ID="$(grep -Eo '[0-9a-fA-F-]{36}' /tmp/opendriver-tunnel-info.txt | head -n 1 || true)"
  fi

  if [ -z "$TUNNEL_ID" ]; then
    cloudflared tunnel create "$TUNNEL_NAME"
    cloudflared tunnel info "$TUNNEL_NAME" >/tmp/opendriver-tunnel-info.txt
    TUNNEL_ID="$(grep -Eo '[0-9a-fA-F-]{36}' /tmp/opendriver-tunnel-info.txt | head -n 1 || true)"
  fi
fi

if [ -z "$TUNNEL_ID" ]; then
  echo "Could not detect tunnel id. Put CLOUDFLARE_TUNNEL_ID in .env and run again."
  exit 1
fi

install -d -m 0700 /root/.cloudflared
sed "s/TUNNEL_ID/$TUNNEL_ID/g" "$SCRIPT_DIR/cloudflared/config.yml" > /root/.cloudflared/config.yml

cloudflared tunnel route dns "$TUNNEL_NAME" "$DOMAIN" || true
cloudflared tunnel route dns "$TUNNEL_NAME" "$WWW_DOMAIN" || true

cloudflared service install || true
systemctl enable cloudflared >/dev/null
systemctl restart cloudflared

if grep -q '^CLOUDFLARE_TUNNEL_ID=' "$ENV_FILE"; then
  sed -i "s/^CLOUDFLARE_TUNNEL_ID=.*/CLOUDFLARE_TUNNEL_ID=$TUNNEL_ID/" "$ENV_FILE"
else
  echo "CLOUDFLARE_TUNNEL_ID=$TUNNEL_ID" >> "$ENV_FILE"
fi

echo ""
echo "Cloudflare Tunnel configured."
echo "Domain: https://$DOMAIN"
echo "WWW:    https://$WWW_DOMAIN"
systemctl --no-pager status cloudflared || true
