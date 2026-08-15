# Termux Android Lab

A public experiment: using an Android smartphone as a small web server, serving
a static site from Termux, and publishing it on the Internet with a real domain.

## Public demo

**Site:** [termux.tongatron.org](https://termux.tongatron.org/)

The demo is served by a Redmi 12. It shows the device and service status, but
the approach is general: replace this page with a portfolio, documentation,
dashboard, or any other static site.

> This is a learning lab, not professional hosting. Android may suspend or
> terminate Termux, the network may change, and the phone may be switched off.

## The idea in one line

```text
Browser → Cloudflare → Cloudflare Tunnel → cloudflared on Android
                                      → 127.0.0.1:8080
                                      → Python http.server → ~/www
```

The tunnel opens an **outbound** connection to Cloudflare: no router
port-forwarding, static public IP, or Tailscale is required. Tailscale is only
useful for administering the phone remotely.

## 1. First step: connect to Android over SSH

This is the foundation. Once SSH is configured, deployment, logs, and service
restarts can all be handled from a Mac or PC.

### On the Android phone, in Termux

```bash
pkg update
pkg install openssh
passwd                         # temporary password for the first login
sshd                           # starts SSH on port 8022
whoami                         # note the Termux username
```

Find the phone's address:

- Wi-Fi: **Settings → Wi-Fi → connected network → IP address**;
- Tailscale: open the app and use the Android device's address.

Tailscale is not needed to publish the site. It is simply a convenient, stable
channel for remote administration.

### From the Mac/PC: first login

Replace the placeholders with the values you noted:

```bash
ssh -p 8022 <termux-user>@<phone-ip>
```

Accept the host key and enter the temporary password. Then install an SSH key
so that future logins do not require a password:

```bash
test -f ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub | \
  ssh -p 8022 <termux-user>@<phone-ip> \
  'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys'
```

### Permanent SSH alias

Add this to `~/.ssh/config` on the Mac/PC:

```sshconfig
Host termux-phone
    HostName <phone-lan-or-tailscale-ip>
    Port 8022
    User <termux-user>
    IdentityFile ~/.ssh/id_ed25519
```

Final test:

```bash
ssh termux-phone 'whoami && hostname && pwd'
```

Now fill in [`config.example.env`](config.example.env), save it as
`config.env`, and use `make deploy`, `make status`, `make logs`, and
`make restart`.

## What is in this project

| File | Purpose |
| --- | --- |
| [`index.html`](index.html) | main demo page |
| [`guida.html`](guida.html) | web-accessible guide |
| [`boot-start-services.sh`](boot-start-services.sh) | starts services after boot |
| [`sysinfo.sh`](sysinfo.sh) | generates device status data |
| [`camera.html`](camera.html) | optional camera module page |
| [`come-hostare-una-pagina-con-termux.md`](come-hostare-una-pagina-con-termux.md) | step-by-step guide |
| [`Pocket-Dev-Server.md`](Pocket-Dev-Server.md) | notes on using a phone as a pocket server |

Operational notes containing local addresses and network details are kept out
of the public repository.

## Recommended workflow

The repository separates the explanation from the repeatable operations:

| Path | Contents |
| --- | --- |
| [`docs/`](docs/) | how-to guides for installation, SSH, hosting, autostart, and troubleshooting |
| [`scripts/`](scripts/) | repeatable bootstrap, deploy, status, log, and restart commands |
| [`config.example.env`](config.example.env) | SSH configuration template to copy to `config.env` |
| [`Makefile`](Makefile) | short command interface for the computer |

The daily Mac/PC workflow becomes:

```bash
cp config.example.env config.env   # once: enter host and username
make check                          # validate the scripts
make deploy                         # publish the site to Termux
make status                         # check the services
make logs                           # read the tunnel log
```

For the complete path, start with
[`docs/01-installazione.md`](docs/01-installazione.md).

## Quick start: local web server

In Termux:

```bash
pkg update
pkg install python

mkdir -p ~/www
cp index.html ~/www/
python -m http.server 8080 --directory ~/www --bind 127.0.0.1
```

The site is now available locally on the phone:

```bash
curl -I http://127.0.0.1:8080/
```

Binding to `127.0.0.1` is intentional: the server is not directly exposed to
the local network. `cloudflared` is the only public entry point.

## Publish with Cloudflare Tunnel

For a quick test, use a random temporary URL:

```bash
pkg install cloudflared
cloudflared tunnel --url http://127.0.0.1:8080
```

For a stable domain, use a **named tunnel**. The minimum configuration is:

```yaml
tunnel: <tunnel-id>
credentials-file: /data/data/com.termux/files/home/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: example.yourdomain.com
    service: http://127.0.0.1:8080
  - service: http_status:404
```

Connect the DNS record and start the tunnel:

```bash
cloudflared tunnel route dns <tunnel-name> example.yourdomain.com
cloudflared tunnel run <tunnel-name>
```

Tunnel credentials are private: never commit or publish them, and do not put
them in article logs.

## Automatic startup after reboot

The project uses one script to start `sshd`, the Python server, the status loop,
and `cloudflared`:

```bash
mkdir -p ~/.termux/boot
chmod +x ~/.termux/boot/start-services
```

Copy the file to `~/.termux/boot/start-services`; the template is
[`boot-start-services.sh`](boot-start-services.sh).

On Termux from Google Play, boot support is integrated into the main app. On
F-Droid/GitHub installations, install the
[Termux:Boot](https://github.com/termux/termux-boot) add-on and open it once.

On Xiaomi/MIUI, also enable:

```text
Settings → Apps → Termux → Autostart
Settings → Apps → Termux → Battery → No restrictions
```

The script uses `termux-wake-lock`, but no software setting can guarantee that
Android will never terminate Termux. For important services, use a Raspberry
Pi, mini-PC, or VPS instead.

## Quick diagnosis

```bash
pgrep -laf 'http.server|cloudflared|sshd|sysinfo'
curl -I http://127.0.0.1:8080/
tail -n 80 ~/cloudflared-termux.log
```

The most useful symptoms to recognize:

| Symptom | Likely meaning |
| --- | --- |
| `HTTP 530`, `error code: 1033` | no `cloudflared` process is connected to Cloudflare |
| `HTTP 502` | the tunnel is connected, but the local service on port 8080 is not responding |
| `connection refused` on SSH | Termux or `sshd` is stopped, or the phone is offline |

## Security and privacy

- everything placed in `~/www` becomes public;
- never publish tokens, certificates, SSH keys, or log files;
- review `info.json` before exposing device data;
- keep Termux and its packages up to date;
- put authentication in front of private pages;
- disable or protect optional endpoints such as the camera.

## Why do this?

To learn and make the complete web publishing path visible: static files, a
local process, a tunnel, DNS, HTTPS, autostart, and Android's limitations. It
turns an old phone into a small laboratory that fits in your pocket.

For a static site that must stay online without depending on the phone, use
[Cloudflare Pages](https://pages.cloudflare.com/), GitHub Pages, or a dedicated
server instead.

## License and reuse

The files are intended as educational material and can be adapted to your own
device, domain, and provider. Before copying the configuration, replace all
names, addresses, and paths that are specific to the original installation.
