#!/data/data/com.termux/files/usr/bin/bash
# Scatta una foto con la fotocamera frontale ogni INTERVAL secondi, tiene le
# ultime KEEP e aggiorna il manifest letto da ~/www/camera/index.html.
#
#   setsid nohup ~/camera-loop.sh < /dev/null > ~/camera-loop.log 2>&1 & disown
#   pkill -f camera-loop.sh    per fermarlo
#
# ---------------------------------------------------------------------------
# DUE BACKEND, scelti automaticamente in quest'ordine.
#
# 1. "ipwebcam" (in uso) - l'app IP Webcam espone uno snapshot JPEG su
#    /shot.jpg. Gira come foreground service, quindi Android le lascia la
#    fotocamera anche a schermo spento: e l'unico modo per avere scatti 24/7.
#
#    ATTENZIONE: IP Webcam ascolta sull'interfaccia Wi-Fi, NON su loopback,
#    quindi va contattata al'IP LAN del telefono. Quell'IP e assegnato via
#    DHCP e cambia, e Android 15 impedisce a Termux di leggerlo (netlink e
#    /proc/net negati da SELinux). Per questo lo script memorizza l'ultimo URL
#    funzionante in ~/.camera-url e, quando smette di rispondere, ripercorre
#    la stessa /24 per ritrovare la porta aperta e si riconfigura da solo.
#
# 2. "termux" - termux-camera-photo del pacchetto termux-api. NON funziona
#    sulla build Termux del Play Store (TERMUX_VERSION=googleplay.*), che
#    risponde "Termux:API is not yet available on Google Play". Serve Termux
#    da F-Droid/GitHub piu l'app Termux:API, e anche cosi Android blocca la
#    fotocamera alle app in background: scatti solo con Termux in primo piano.
# ---------------------------------------------------------------------------

set -u

INTERVAL=10          # secondi tra uno scatto e l'altro
KEEP=30              # quante foto conservare
CAMERA_ID=1          # backend termux: 0 = posteriore, 1 = frontale
CAM_PORT=8081        # porta del server IP Webcam

DIR="$HOME/www/camera"
SHOTS="$DIR/shots"
MANIFEST="$DIR/shots.json"
URL_FILE="$HOME/.camera-url"
# Sostituire con l'indirizzo del dispositivo che esegue IP Webcam.
DEFAULT_URL="http://192.168.1.100:$CAM_PORT/shot.jpg"
# Su Termux /tmp non esiste e non e scrivibile: usare TMPDIR ($PREFIX/tmp).
ERR_FILE="${TMPDIR:-$HOME}/camera-loop.err"

mkdir -p "$SHOTS"

CAM_URL="$(cat "$URL_FILE" 2>/dev/null || echo "$DEFAULT_URL")"

alive() { curl -fsS -m 5 -o /dev/null "$1" 2>/dev/null; }

# Cerca IP Webcam sulla /24 dell'ultimo URL noto. Serve dopo un cambio di IP
# via DHCP, visto che il telefono non puo leggere il proprio indirizzo.
#
# Sonde in parallelo a gruppi di 32 con timeout di 1s: in sequenza la
# scansione bloccava il loop per minuti quando l'app era semplicemente spenta,
# ed e il caso piu frequente. Backoff di DISCOVERY_EVERY secondi per non
# rifarla a ogni giro a vuoto: se il server e giu, ritrovarlo e impossibile e
# insistere serve solo a fermare il loop.
DISCOVERY_EVERY=180
LAST_DISCOVERY=0

rediscover() {
  local now prefix host found_file
  now="$(date +%s)"
  [ $((now - LAST_DISCOVERY)) -ge "$DISCOVERY_EVERY" ] || return 1
  LAST_DISCOVERY="$now"

  prefix="$(printf '%s' "$CAM_URL" | sed -n 's|http://\([0-9]*\.[0-9]*\.[0-9]*\)\.[0-9]*:.*|\1|p')"
  [ -n "$prefix" ] || return 1

  found_file="${TMPDIR:-$HOME}/camera-found"
  rm -f "$found_file"
  echo "IP Webcam non risponde, cerco su $prefix.0/24..."

  for host in $(seq 1 254); do
    (
      url="http://$prefix.$host:$CAM_PORT/shot.jpg"
      curl -fsS --connect-timeout 1 -m 2 -o /dev/null "$url" 2>/dev/null &&
        printf '%s' "$url" > "$found_file"
    ) &
    [ $((host % 32)) -eq 0 ] && wait
  done
  wait

  [ -s "$found_file" ] || { echo "nessun server trovato sulla /24"; return 1; }
  CAM_URL="$(cat "$found_file")"
  printf '%s\n' "$CAM_URL" > "$URL_FILE"
  echo "trovata: $CAM_URL"
  curl -fsS -m 5 -o /dev/null "${CAM_URL%/shot.jpg}/settings/ffc?set=on" 2>/dev/null
}

# --- scelta del backend ----------------------------------------------------
BACKEND=""
if command -v curl >/dev/null 2>&1; then
  if alive "$CAM_URL" || rediscover; then
    BACKEND="ipwebcam"
    printf '%s\n' "$CAM_URL" > "$URL_FILE"
    # IP Webcam parte sulla fotocamera posteriore: ffc=front facing camera.
    curl -fsS -m 5 -o /dev/null "${CAM_URL%/shot.jpg}/settings/ffc?set=on" 2>/dev/null &&
      echo "fotocamera frontale attivata" || echo "nota: non ho potuto forzare la frontale"
    sleep 2
  fi
fi
if [ -z "$BACKEND" ] && command -v termux-camera-photo >/dev/null 2>&1 &&
   ! termux-camera-photo -c "$CAMERA_ID" /dev/null 2>&1 | grep -q "not yet available"; then
  BACKEND="termux"
fi

if [ -z "$BACKEND" ]; then
  cat >&2 <<'MSG'
Nessun backend fotocamera disponibile.

Opzione A (in uso, funziona a schermo spento):
  avvia il server nell'app IP Webcam sulla porta 8081 e rilancia lo script.

Opzione B:
  sostituisci Termux con la build F-Droid/GitHub e installa l'app Termux:API
  (gli scatti funzioneranno solo con Termux in primo piano).
MSG
  exit 1
fi

echo "backend fotocamera: $BACKEND${CAM_URL:+ ($CAM_URL)}"

esc() { printf '%s' "${1-}" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# Ricostruisce shots.json dai file presenti, dal piu recente al piu vecchio.
write_manifest() {
  local err="$1" first=1 f base ts bytes
  {
    printf '{\n'
    printf '  "updated": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "interval_s": %s,\n' "$INTERVAL"
    printf '  "keep": %s,\n' "$KEEP"
    printf '  "backend": "%s",\n' "$(esc "$BACKEND")"
    printf '  "last_error": "%s",\n' "$(esc "$err")"
    printf '  "shots": [\n'
    for f in $(ls -1t "$SHOTS"/*.jpg 2>/dev/null | head -n "$KEEP"); do
      base="$(basename "$f")"
      # 20260727-084012.jpg -> 2026-07-27 08:40:12
      ts="${base%.jpg}"
      ts="${ts:0:4}-${ts:4:2}-${ts:6:2} ${ts:9:2}:${ts:11:2}:${ts:13:2}"
      bytes="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"
      [ $first -eq 1 ] || printf ',\n'
      first=0
      printf '    {"file": "shots/%s", "ts": "%s", "bytes": %s}' \
        "$(esc "$base")" "$ts" "${bytes:-0}"
    done
    [ $first -eq 1 ] || printf '\n'
    printf '  ]\n}\n'
  } > "$MANIFEST.tmp"
  mv "$MANIFEST.tmp" "$MANIFEST"
}

# Cancella gli scatti oltre i KEEP piu recenti.
prune() {
  local f
  for f in $(ls -1t "$SHOTS"/*.jpg 2>/dev/null | tail -n +$((KEEP + 1))); do
    rm -f "$f"
  done
}

capture() {
  case "$BACKEND" in
    ipwebcam) curl -fsS -m "$INTERVAL" -o "$1" "$CAM_URL" 2>"$ERR_FILE" ;;
    termux)   timeout 25 termux-camera-photo -c "$CAMERA_ID" "$1" 2>"$ERR_FILE" ;;
  esac
}

trap 'write_manifest "loop fermato"; exit 0' INT TERM

write_manifest "avvio in corso"
fails=0

while true; do
  target="$SHOTS/$(date +%Y%m%d-%H%M%S).jpg"

  if capture "$target" && [ -s "$target" ]; then
    last_error=""
    fails=0
  else
    rm -f "$target"
    last_error="$(head -c 200 "$ERR_FILE" 2>/dev/null)"
    [ -n "$last_error" ] || last_error="scatto fallito o vuoto (backend $BACKEND)"
    fails=$((fails + 1))
    # Tre fallimenti di fila: probabile cambio di IP, riprova la scoperta.
    if [ "$BACKEND" = "ipwebcam" ] && [ $fails -ge 3 ]; then
      rediscover && fails=0
    fi
  fi

  prune
  write_manifest "$last_error"
  sleep "$INTERVAL"
done
