#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

# Eseguire sul telefono dopo aver clonato la repo in ~/termux-android.
REPO_DIR="${REPO_DIR:-$HOME/termux-android}"

if [[ ! -f "$REPO_DIR/boot-start-services.sh" ]]; then
  printf 'Repository non trovata in %s\n' "$REPO_DIR" >&2
  exit 1
fi

pkg update
pkg install -y openssh python cloudflared

mkdir -p "$HOME/www" "$HOME/.termux/boot"
cp "$REPO_DIR/boot-start-services.sh" "$HOME/.termux/boot/start-services"
chmod +x "$HOME/.termux/boot/start-services"

for file in index.html guida.html camera.html; do
  [[ -f "$REPO_DIR/$file" ]] && cp "$REPO_DIR/$file" "$HOME/www/$file"
done

printf '\nBootstrap completato.\n'
printf '%s\n' 'Abilita Avvio automatico e Nessuna restrizione batteria per Termux nelle impostazioni Android.'
printf '%s\n' 'Poi configura ~/.cloudflared/config.yml e prova: bash ~/.termux/boot/start-services'
