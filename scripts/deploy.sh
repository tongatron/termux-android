#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="${CONFIG_FILE:-config.env}"
if [[ ! -f "$CONFIG_FILE" ]]; then
  printf 'Missing configuration: %s\n' "$CONFIG_FILE" >&2
  printf 'Copy config.example.env to config.env and fill it in.\n' >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

: "${TERMUX_HOST:?TERMUX_HOST is not set}"
: "${TERMUX_USER:?TERMUX_USER is not set}"
: "${SSH_PORT:?SSH_PORT is not set}"
: "${REMOTE_WWW:?REMOTE_WWW is not set}"

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

printf 'Preparing %s…\n' "$TARGET"
"${SSH[@]}" "$TARGET" "mkdir -p $REMOTE_WWW/guida $REMOTE_WWW/camera"

printf 'Publishing files…\n'
copy_file "${SITE_INDEX:-index.html}" index.html
copy_file "${SITE_GUIDE:-guida.html}" guida/index.html
copy_file "${SITE_CAMERA:-camera.html}" camera/index.html

printf 'Deploy complete. Verify with: make status\n'
