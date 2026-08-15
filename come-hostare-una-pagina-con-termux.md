# How to host a web page on Android with Termux

A self-contained guide to publishing a static site from an Android phone,
using [Termux](https://termux.dev/) as a Linux environment without root. For
the public workflow, start with the English [README](README.md) and the guides
in [`docs/`](docs/).

## Requirements

- An Android phone with **Termux** installed (Google Play or F-Droid/GitHub).
- A Mac/PC on the same network (or connected through Tailscale) for comfortable
  keyboard-based administration.
- For a public URL: a free [Cloudflare](https://cloudflare.com) account. A
  paid domain is not required for a temporary Quick Tunnel URL.

**Google Play vs F-Droid**: the Google Play build uses the `https://termux.net`
repository; the F-Droid/GitHub build uses `packages.termux.dev`. Some Termux:API
features are not available in the Google Play build. This does not affect basic
web hosting.

## 1. Initial Termux setup

Open the Termux app on the phone:

```bash
pkg update && pkg upgrade -y
pkg install -y openssh python net-tools
```

- `openssh` — administer the phone from a Mac/PC
- `python` — includes the `http.server` module
- `net-tools` — optional network utilities (limited on Android 15+)

## 2. SSH access from a Mac/PC

On the phone:

```bash
passwd        # temporary password for the first key installation
sshd
whoami        # note the Termux username
```

Find the phone IP in **Settings → Wi-Fi → connected network → details**. On
Android 15, `ip addr` and `ifconfig` may fail because of SELinux. Then connect:

```bash
ssh -p 8022 <termux-user>@<phone-ip>
```

Termux uses port `8022`, not the privileged SSH port `22`. Install a key so
future sessions do not require a password:

```bash
test -f ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub | \
  ssh -p 8022 <termux-user>@<phone-ip> \
  'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys'
```

## 3. Serve the page

On the phone (or over SSH):

```bash
mkdir -p ~/www
# copy index.html and the other static files here
python -m http.server 8080 --directory ~/www --bind 127.0.0.1
```

Binding to `127.0.0.1` keeps the server on the phone and makes it reachable
through a tunnel, but not directly from the local network. To expose it on the
LAN, omit `--bind` or use `--bind 0.0.0.0`.

From the Mac/PC, a single file can be copied with:

```bash
scp -P 8022 index.html <termux-user>@<phone-ip>:~/www/index.html
```

For the repeatable workflow, use `make deploy` from the main README.

## 4. Keep it running in the background

When the SSH session closes, a foreground `http.server` normally exits. Detach
it with:

```bash
setsid nohup python -m http.server 8080 --directory ~/www --bind 127.0.0.1 \
  < /dev/null > ~/webserver.log 2>&1 & disown
```

`nohup ... &` alone is not always enough: `setsid` detaches the process from
the session and `/dev/null` prevents it from waiting on a closed terminal.

## 5. Publish it with Cloudflare Tunnel

```bash
pkg install cloudflared
```

### Quick option (random URL)

No login is required, but the URL changes and there is no uptime guarantee:

```bash
cloudflared tunnel --url http://127.0.0.1:8080
```

The log prints a URL such as `https://random-words.trycloudflare.com`.

### Stable option (fixed domain)

A **named tunnel** requires an interactive login the first time:

```bash
cloudflared tunnel login
cloudflared tunnel create <tunnel-name>
```

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: <tunnel-id>
credentials-file: /data/data/com.termux/files/home/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: subdomain.yourdomain.org
    service: http://127.0.0.1:8080
  - service: http_status:404
```

Connect DNS and start it:

```bash
cloudflared tunnel route dns <tunnel-name> subdomain.yourdomain.org

setsid nohup cloudflared tunnel run <tunnel-name> \
  < /dev/null > ~/cloudflared.log 2>&1 & disown
```

If login is performed over SSH without a screen, open the printed URL on
another device already signed in to the intended Cloudflare account.

## 6. Keep Termux alive with the screen off

Android suspends background apps to save battery. For a service that should
remain available:

```bash
termux-wake-lock
```

This keeps the CPU awake while the screen is off. It does not keep the display
on.

Also remove Termux battery restrictions:

```text
Settings → Apps → Termux → Battery → No restrictions
Settings → Apps → Termux → Autostart (if available, e.g. MIUI)
```

Without these settings, Xiaomi/MIUI may terminate Termux even with a wake lock.

## 7. Start automatically after reboot

Place an executable script in `~/.termux/boot/`. The ready-to-use version is
[`boot-start-services.sh`](boot-start-services.sh):

```bash
mkdir -p ~/.termux/boot
cp ~/termux-android/boot-start-services.sh ~/.termux/boot/start-services
chmod +x ~/.termux/boot/start-services
```

On Google Play Termux, boot support is integrated into the main app. On
F-Droid/GitHub installations, install and open
[Termux:Boot](https://github.com/termux/termux-boot) once.

Android must be allowed to deliver the boot event to Termux; enable the
**Autostart** permission in MIUI/Xiaomi settings.

## Useful command cheat sheet

| Command | Purpose |
|---|---|
| `sshd` | start SSH on port 8022 |
| `pgrep sshd` | check whether SSH is running |
| `pkill sshd` | stop SSH |
| `termux-wake-lock` | keep the CPU awake with the screen off |
| `termux-wake-unlock` | release the wake lock |
| `python -m http.server 8080 --directory ~/www --bind 127.0.0.1` | serve the site on port 8080 |
| `setsid nohup <command> < /dev/null > log.txt 2>&1 & disown` | detach a background process from SSH |
| `cloudflared tunnel --url http://127.0.0.1:8080` | start a temporary public tunnel |
| `cloudflared tunnel list` | list named tunnels in the account |
| `pgrep -laf "http.server\|cloudflared\|sshd"` | show the main services |
| `scp -P 8022 file <user>@<host>:~/path` | copy a file from the Mac/PC |
| `ssh -p 8022 <user>@<host>` | connect to the phone |

## Limitations

- **This is not a 24/7 server replacement.** Android can kill background apps,
  especially on MIUI/Xiaomi, even with a wake lock and the right permissions.
- **Android 15+ may block `ip addr`/`ifconfig` in Termux** because of SELinux;
  read the local IP from Android settings instead.
- **`/tmp` may not exist in Termux**; use `$TMPDIR` (`$PREFIX/tmp`) for
  temporary files.
- **DHCP addresses change.** For stable SSH administration, use Tailscale or a
  fixed DHCP lease on the router.
