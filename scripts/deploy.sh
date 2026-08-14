#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="${CONFIG_FILE:-config.env}"
if [[ ! -f "$CONFIG_FILE" ]]; then
  printf 'Configurazione mancante: %s\n' "$CONFIG_FILE" >&2
  printf 'Copia config.example.env in config.env e compilalo.\n' >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

: "${TERMUX_HOST:?TERMUX_HOST non impostato}"
: "${TERMUX_USER:?TERMUX_USER non impostato}"
: "${SSH_PORT:?SSH_PORT non impostato}"
: "${REMOTE_WWW:?REMOTE_WWW non impostato}"

TARGET="${TERMUX_USER}@${TERMUX_HOST}"
SSH=(ssh -p "$SSH_PORT")
SCP=(scp -P "$SSH_PORT")

copy_file() {
  local source_file="$1"
  local remote_file="$2"
  if [[ -f "$source_file" ]]; then
    "${SCP[@]}" "$source_file" "$TARGET:$REMOTE_WWW/$remote_file"
    printf '  %-24s → %s\n' "$source_file" "$remote_file"
  fi
}

printf 'Preparo %s…\n' "$TARGET"
"${SSH[@]}" "$TARGET" "mkdir -p $REMOTE_WWW/guida $REMOTE_WWW/camera"

printf 'Pubblico i file…\n'
copy_file "${SITE_INDEX:-index.html}" index.html
copy_file "${SITE_GUIDE:-guida.html}" guida/index.html
copy_file "${SITE_CAMERA:-camera.html}" camera/index.html

printf 'Deploy completato. Verifica con: make status\n'
