#!/data/data/com.termux/files/usr/bin/bash
# Run by Termux at phone boot (~/.termux/boot/start-services).
# Idempotently starts sshd, the web server, the sysinfo loop, and cloudflared.
#
# camera-loop.sh is intentionally excluded: the camera module is optional and
# is not started by the base workflow.

set -u

termux-wake-lock
mkdir -p "$HOME/www"

if ! pgrep -x sshd >/dev/null 2>&1; then
  sshd
fi

start_once() {
  local pattern="$1"
  local logfile="$2"
  shift 2

  if pgrep -f "$pattern" >/dev/null 2>&1; then
    return 0
  fi

  setsid nohup "$@" < /dev/null > "$logfile" 2>&1 &
}

start_once 'python -m http.server 8080' "$HOME/webserver.log" \
  python -m http.server 8080 --directory "$HOME/www" --bind 127.0.0.1

start_once 'sysinfo.sh loop' "$HOME/sysinfo.log" \
  "$HOME/sysinfo.sh" loop

start_once 'cloudflared tunnel run termux-redmi12' "$HOME/cloudflared-termux.log" \
  cloudflared tunnel run termux-redmi12
