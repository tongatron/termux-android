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

ssh -p "$SSH_PORT" "${TERMUX_USER}@${TERMUX_HOST}" \
  'tail -n 100 "$HOME/cloudflared-termux.log"'
