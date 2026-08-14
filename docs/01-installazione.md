# 1. Installazione

Questo how-to usa Termux come ambiente Linux su Android e Python come server
HTTP locale. Il telefono non deve avere root.

## Prerequisiti

- Termux installato da una fonte coerente (Google Play oppure F-Droid/GitHub);
- un computer per il primo accesso SSH;
- un dominio gestito da Cloudflare se vuoi un indirizzo stabile;
- una rete Wi-Fi o mobile affidabile.

## Pacchetti

In Termux:

```bash
pkg update && pkg upgrade -y
pkg install -y openssh python cloudflared git
```

## Repository sul telefono

```bash
cd ~
git clone https://github.com/tongatron/termux-android.git
cd ~/termux-android
bash scripts/bootstrap-termux.sh
```

Se il telefono deve soltanto servire i file, puoi anche copiare il sito dal
computer con `make deploy` senza mantenere una copia Git sul dispositivo.

## Server locale

```bash
mkdir -p ~/www
python -m http.server 8080 --directory ~/www --bind 127.0.0.1
```

Il server ascolta solo sul loopback. L'accesso pubblico passerà dal tunnel.
