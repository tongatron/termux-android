# 4. Avvio automatico

Il file [`boot-start-services.sh`](../boot-start-services.sh) avvia in modo
idempotente SSH, il server Python, il generatore di stato e `cloudflared`.

Su Termux dal Google Play Store il supporto boot è integrato nell'app
principale. Su F-Droid/GitHub installa [Termux:Boot](https://github.com/termux/termux-boot),
aprilo una volta e poi usa `~/.termux/boot/`.

In Termux:

```bash
mkdir -p ~/.termux/boot
cp ~/termux-android/boot-start-services.sh ~/.termux/boot/start-services
chmod +x ~/.termux/boot/start-services
bash ~/.termux/boot/start-services
```

Su Xiaomi/MIUI abilita anche:

```text
Impostazioni → App → Termux → Avvio automatico
Impostazioni → App → Termux → Batteria → Nessuna restrizione
```

Android può comunque terminare un'app in background. L'autostart riduce gli
interventi manuali, ma non equivale a un servizio 24/7.
