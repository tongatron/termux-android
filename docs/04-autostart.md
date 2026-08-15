# 4. Automatic startup

[`boot-start-services.sh`](../boot-start-services.sh) starts `sshd`, the Python
server, the status loop, and `cloudflared` in an idempotent way.

On Google Play Termux, boot support is integrated into the main app. On
F-Droid/GitHub installations, install [Termux:Boot](https://github.com/termux/termux-boot),
open it once, and use `~/.termux/boot/`.

In Termux:

```bash
mkdir -p ~/.termux/boot
cp ~/termux-android/boot-start-services.sh ~/.termux/boot/start-services
chmod +x ~/.termux/boot/start-services
bash ~/.termux/boot/start-services
```

On Xiaomi/MIUI, also enable:

```text
Settings → Apps → Termux → Autostart
Settings → Apps → Termux → Battery → No restrictions
```

Android may still terminate a background app. Autostart reduces manual work,
but it is not a 24/7 guarantee.
