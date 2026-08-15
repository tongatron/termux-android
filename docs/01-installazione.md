# 1. Installation

This how-to uses Termux as a Linux environment on Android and Python as the
local HTTP server. The phone does not need root access.

## Requirements

- Termux installed from one consistent source (Google Play or F-Droid/GitHub);
- a computer for the first SSH connection;
- a Cloudflare-managed domain if you want a stable public address;
- a reliable Wi-Fi or mobile connection.

## Packages

In Termux:

```bash
pkg update && pkg upgrade -y
pkg install -y openssh python cloudflared git
```

## Repository on the phone

```bash
cd ~
git clone https://github.com/tongatron/termux-android.git
cd ~/termux-android
bash scripts/bootstrap-termux.sh
```

If the phone only needs to serve files, you can skip the Git checkout and copy
the site from the computer with `make deploy`.

## Local server

```bash
mkdir -p ~/www
python -m http.server 8080 --directory ~/www --bind 127.0.0.1
```

The server listens only on loopback. Public access is provided by the tunnel.
