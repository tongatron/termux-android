#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

# Run on the phone after cloning the repository to ~/termux-android.
REPO_DIR="${REPO_DIR:-$HOME/termux-android}"

if [[ ! -f "$REPO_DIR/boot-start-services.sh" ]]; then
  printf 'Repository not found at %s\n' "$REPO_DIR" >&2
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

printf '\nBootstrap complete.\n'
printf '%s\n' 'Enable Autostart and No battery restrictions for Termux in Android settings.'
printf '%s\n' 'Then configure ~/.cloudflared/config.yml and try: bash ~/.termux/boot/start-services'
