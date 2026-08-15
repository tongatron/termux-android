#!/data/data/com.termux/files/usr/bin/bash
# Takes a front-camera photo every INTERVAL seconds, keeps the latest KEEP
# images, and updates the manifest read by ~/www/camera/index.html.
#
#   setsid nohup ~/camera-loop.sh < /dev/null > ~/camera-loop.log 2>&1 & disown
#   pkill -f camera-loop.sh    to stop it
#
# ---------------------------------------------------------------------------
# TWO BACKENDS, selected automatically in this order.
#
# 1. "ipwebcam" (used) - the IP Webcam app exposes a JPEG snapshot at
#    /shot.jpg. It runs as a foreground service, so Android leaves the camera
#    available with the screen off: the only practical way to capture 24/7.
#
#    WARNING: IP Webcam listens on the Wi-Fi interface, NOT loopback, so it
#    must be reached through the phone's LAN IP. That address comes from DHCP
#    and can change; Android 15 also prevents Termux from reading it (netlink
#    and /proc/net are blocked by SELinux). The script therefore stores the
#    last working URL in ~/.camera-url and scans the same /24 when it stops
#    responding, reconfiguring itself automatically.
#
# 2. "termux" - termux-camera-photo from the termux-api package. It does NOT
#    work on the Google Play Termux build (TERMUX_VERSION=googleplay.*), which
#    returns "Termux:API is not yet available on Google Play". Use the
#    F-Droid/GitHub Termux build plus the Termux:API app; even then Android
#    blocks camera access for background apps, so capture works only with
#    Termux in the foreground.
# ---------------------------------------------------------------------------

set -u

INTERVAL=10          # seconds between shots
KEEP=30              # number of images to retain
CAMERA_ID=1          # termux backend: 0 = rear, 1 = front
CAM_PORT=8081        # IP Webcam server port

DIR="$HOME/www/camera"
SHOTS="$DIR/shots"
MANIFEST="$DIR/shots.json"
URL_FILE="$HOME/.camera-url"
# Replace with the address of the device running IP Webcam.
DEFAULT_URL="http://192.168.1.100:$CAM_PORT/shot.jpg"
# Termux may not have a writable /tmp: use TMPDIR ($PREFIX/tmp).
ERR_FILE="${TMPDIR:-$HOME}/camera-loop.err"

mkdir -p "$SHOTS"

CAM_URL="$(cat "$URL_FILE" 2>/dev/null || echo "$DEFAULT_URL")"

alive() { curl -fsS -m 5 -o /dev/null "$1" 2>/dev/null; }

# Search for IP Webcam on the /24 of the last known URL. This handles a DHCP
# address change because the phone cannot read its own address.
#
# Probe in parallel batches of 32 with a one-second timeout. Sequential scans
# blocked the loop for minutes when the app was simply off, which is common.
# Use a DISCOVERY_EVERY-second backoff: if the server is down, repeating the
# scan every cycle cannot help and only stalls the loop.
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
  echo "IP Webcam is not responding; scanning $prefix.0/24..."

  for host in $(seq 1 254); do
    (
      url="http://$prefix.$host:$CAM_PORT/shot.jpg"
      curl -fsS --connect-timeout 1 -m 2 -o /dev/null "$url" 2>/dev/null &&
        printf '%s' "$url" > "$found_file"
    ) &
    [ $((host % 32)) -eq 0 ] && wait
  done
  wait

  [ -s "$found_file" ] || { echo "no server found on the /24"; return 1; }
  CAM_URL="$(cat "$found_file")"
  printf '%s\n' "$CAM_URL" > "$URL_FILE"
  echo "found: $CAM_URL"
  curl -fsS -m 5 -o /dev/null "${CAM_URL%/shot.jpg}/settings/ffc?set=on" 2>/dev/null
}

# --- backend selection -----------------------------------------------------
BACKEND=""
if command -v curl >/dev/null 2>&1; then
  if alive "$CAM_URL" || rediscover; then
    BACKEND="ipwebcam"
    printf '%s\n' "$CAM_URL" > "$URL_FILE"
    # IP Webcam starts on the rear camera: ffc means front-facing camera.
    curl -fsS -m 5 -o /dev/null "${CAM_URL%/shot.jpg}/settings/ffc?set=on" 2>/dev/null &&
      echo "front camera enabled" || echo "note: could not force the front camera"
    sleep 2
  fi
fi
if [ -z "$BACKEND" ] && command -v termux-camera-photo >/dev/null 2>&1 &&
   ! termux-camera-photo -c "$CAMERA_ID" /dev/null 2>&1 | grep -q "not yet available"; then
  BACKEND="termux"
fi

if [ -z "$BACKEND" ]; then
  cat >&2 <<'MSG'
No camera backend is available.

Option A (used here, works with the screen off):
  start the server in the IP Webcam app on port 8081 and rerun this script.

Option B:
  replace Termux with the F-Droid/GitHub build and install the Termux:API app
  (capture will work only with Termux in the foreground).
MSG
  exit 1
fi

echo "camera backend: $BACKEND${CAM_URL:+ ($CAM_URL)}"

esc() { printf '%s' "${1-}" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# Rebuild shots.json from the existing files, newest first.
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

# Delete shots beyond the KEEP most recent images.
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

trap 'write_manifest "loop stopped"; exit 0' INT TERM

write_manifest "starting"
fails=0

while true; do
  target="$SHOTS/$(date +%Y%m%d-%H%M%S).jpg"

  if capture "$target" && [ -s "$target" ]; then
    last_error=""
    fails=0
  else
    rm -f "$target"
    last_error="$(head -c 200 "$ERR_FILE" 2>/dev/null)"
    [ -n "$last_error" ] || last_error="capture failed or was empty (backend $BACKEND)"
    fails=$((fails + 1))
    # Three consecutive failures: likely an IP change, retry discovery.
    if [ "$BACKEND" = "ipwebcam" ] && [ $fails -ge 3 ]; then
      rediscover && fails=0
    fi
  fi

  prune
  write_manifest "$last_error"
  sleep "$INTERVAL"
done
