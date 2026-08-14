#!/data/data/com.termux/files/usr/bin/bash
# Eseguito da Termux all'avvio del telefono (~/.termux/boot/start-services su
# Termux, via il boot-runner integrato nell'app Termux dalla versione
# 2024.10.24 in poi: non serve piu l'app separata Termux:Boot). Rilancia tutti
# i demoni che non sopravvivono al riavvio: sshd, web server, sysinfo.sh loop,
# cloudflared.
#
# camera-loop.sh e' escluso di proposito: e' fermato su richiesta dal
# 2026-07-27 (vedi Termolux-android.md, "Loop fotocamera").

termux-wake-lock
sshd

setsid nohup python -m http.server 8080 --directory ~/www --bind 127.0.0.1 \
  < /dev/null > ~/webserver.log 2>&1 &
disown

setsid nohup ~/sysinfo.sh loop < /dev/null > ~/sysinfo.log 2>&1 &
disown

setsid nohup cloudflared tunnel run termux-redmi12 \
  < /dev/null > ~/cloudflared-termux.log 2>&1 &
disown
