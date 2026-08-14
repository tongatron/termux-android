#!/data/data/com.termux/files/usr/bin/bash
# Genera ~/www/info.json con lo stato corrente del telefono, consumato da
# ~/www/index.html via fetch().
#
#   ~/sysinfo.sh              una singola generazione
#   nohup ~/sysinfo.sh loop > ~/sysinfo.log 2>&1 & disown
#
# Nota: su Android 15 /proc/loadavg, /proc/uptime e /proc/net/dev sono negati
# a Termux da SELinux. Il comando `uptime` funziona comunque, `ifconfig` no:
# per questo la pagina non espone indirizzi IP.

set -u

WWW="$HOME/www"
OUT="$WWW/info.json"
INTERVAL=30

# Scappa i caratteri che romperebbero il JSON.
esc() { printf '%s' "${1-}" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/ /g'; }

pkgver() { dpkg-query -W -f='${Version}' "$1" 2>/dev/null || true; }

# true/false JSON a seconda che il processo giri.
running() { if pgrep -f "$1" >/dev/null 2>&1; then printf 'true'; else printf 'false'; fi; }

generate() {
  local up load mem_total mem_used mem_avail st_total st_used st_pct battery

  # `uptime` stampa "HH:MM:SS up 40 min,  load average: 1.0, 2.0, 3.0"
  up="$(uptime 2>/dev/null || true)"
  load="$(printf '%s' "$up" | sed -n 's/.*load average: *//p')"
  up="$(printf '%s' "$up" | sed -n 's/.*up \(.*\), *load average.*/\1/p' | sed 's/^ *//; s/, *$//')"

  read -r _ mem_total mem_used _ _ _ mem_avail <<<"$(free -b 2>/dev/null | sed -n 2p)"

  read -r _ st_total st_used _ st_pct _ <<<"$(df -h "$HOME" 2>/dev/null | tail -1)"

  # termux-battery-status esiste solo con il pacchetto termux-api E l'app
  # Termux:API installata; se manca, il campo resta null.
  battery=""
  if command -v termux-battery-status >/dev/null 2>&1; then
    battery="$(timeout 10 termux-battery-status 2>/dev/null | tr -d '\n' || true)"
  fi
  [ -n "$battery" ] || battery=null

  mkdir -p "$WWW"
  cat > "$OUT.tmp" <<JSON
{
  "generated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "device": {
    "manufacturer": "$(esc "$(getprop ro.product.manufacturer)")",
    "model": "$(esc "$(getprop ro.product.model)")",
    "android": "$(esc "$(getprop ro.build.version.release)")",
    "security_patch": "$(esc "$(getprop ro.build.version.security_patch)")",
    "kernel": "$(esc "$(uname -r)")",
    "arch": "$(esc "$(uname -m)")",
    "cpus": $(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 0)
  },
  "termux": {
    "user": "$(esc "$(whoami)")",
    "home": "$(esc "$HOME")",
    "uptime": "$(esc "$up")",
    "load": "$(esc "$load")"
  },
  "memory": {
    "total_b": ${mem_total:-0},
    "used_b": ${mem_used:-0},
    "available_b": ${mem_avail:-0}
  },
  "storage": {
    "total": "$(esc "${st_total:-}")",
    "used": "$(esc "${st_used:-}")",
    "use_pct": "$(esc "${st_pct:-}")"
  },
  "battery": $battery,
  "packages": {
    "openssh": "$(esc "$(pkgver openssh)")",
    "cloudflared": "$(esc "$(pkgver cloudflared)")",
    "python": "$(esc "$(pkgver python)")",
    "termux-tools": "$(esc "$(pkgver termux-tools)")",
    "termux-api": "$(esc "$(pkgver termux-api)")",
    "net-tools": "$(esc "$(pkgver net-tools)")"
  },
  "services": {
    "sshd": $(running "bin/sshd"),
    "cloudflared": $(running "cloudflared tunnel run"),
    "webserver": $(running "http.server"),
    "camera": $(running "camera-loop.sh")
  }
}
JSON
  mv "$OUT.tmp" "$OUT"
}

if [ "${1:-}" = "loop" ]; then
  while true; do
    generate
    sleep "$INTERVAL"
  done
else
  generate
  echo "scritto $OUT"
fi
