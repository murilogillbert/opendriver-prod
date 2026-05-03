#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "setup.sh now delegates to bootstrap-ubuntu.sh."
bash "$SCRIPT_DIR/bootstrap-ubuntu.sh"
