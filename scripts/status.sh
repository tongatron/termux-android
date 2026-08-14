#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="${CONFIG_FILE:-config.env}"
if [[ ! -f "$CONFIG_FILE" ]]; then
  printf 'Configurazione mancante: %s\n' "$CONFIG_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"
: "${TERMUX_HOST:?TERMUX_HOST non impostato}"
: "${TERMUX_USER:?TERMUX_USER non impostato}"
: "${SSH_PORT:?SSH_PORT non impostato}"

TARGET="${TERMUX_USER}@${TERMUX_HOST}"
ssh -p "$SSH_PORT" "$TARGET" '
  printf "host: "; hostname
  printf "uptime: "; uptime
  printf "\nprocessi:\n"
  pgrep -laf "sshd|http.server|cloudflared|sysinfo" || true
  printf "\nserver locale:\n"
  curl -fsSI --max-time 5 http://127.0.0.1:8080/ | sed -n "1,5p" || true
' 
