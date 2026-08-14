# Come hostare una pagina web su Android con Termux

Guida rapida e autosufficiente per pubblicare un sito statico da un telefono
Android, usando [Termux](https://termux.dev/) come ambiente Linux, senza
root. Per il log dettagliato/troubleshooting di un caso reale (con incidenti,
limiti Android 15/MIUI, fotocamera, ecc.) vedi
[Termolux-android.md](Termolux-android.md).

## Cosa serve

- Un telefono Android con **Termux** installato (Play Store o F-Droid — vedi
  nota sotto sulle differenze).
- Un Mac/PC sulla stessa rete (o via Tailscale) per lavorare comodamente da
  tastiera invece che dal telefono.
- Se vuoi un URL pubblico raggiungibile da internet: un account
  [Cloudflare](https://cloudflare.com) gratuito (non serve un dominio a
  pagamento, Cloudflare ne offre uno casuale con il tunnel "quick").

**Play Store vs F-Droid**: la build Play Store (`TERMUX_VERSION` tipo
`googleplay.*`) usa il repo `https://termux.net`; quella F-Droid/GitHub usa
`packages.termux.dev`. Alcune funzioni di Termux:API (es. scatto fotocamera)
non sono disponibili sulla build Play Store. Per solo web hosting non fa
differenza.

## 1. Setup iniziale in Termux

Sul telefono, apri l'app Termux:

```bash
pkg update && pkg upgrade -y
pkg install -y openssh python net-tools
```

- `openssh` — per lavorare da tastiera Mac/PC invece che dal telefono
- `python` — serve il modulo `http.server` incluso, nessuna installazione a
  parte
- `net-tools` — utility di rete (limitate su Android 15+, vedi sotto)

## 2. Accesso SSH da Mac/PC

Nel telefono:

```bash
passwd        # imposta una password temporanea, serve solo a copiare la chiave
sshd
whoami        # segna l'utente: es. u0_a123
```

Sul Mac/PC, trova l'IP del telefono (**Impostazioni -> Wi-Fi -> rete
connessa -> dettagli**, su Android 15 `ip addr`/`ifconfig` falliscono per
SELinux) e copia la chiave pubblica:

```bash
ssh-copy-id -p 8022 -i ~/.ssh/id_ed25519.pub <utente>@<ip-telefono>
```

Porta `8022`, non `22`: Termux non ha privilegi per la porta SSH standard.
Da quel momento l'accesso è a chiave, senza più password:

```bash
ssh -p 8022 <utente>@<ip-telefono>
```

## 3. Servire la pagina

Nel telefono (o via SSH da qui in poi):

```bash
mkdir -p ~/www
# copiaci dentro index.html e gli altri file statici
python -m http.server 8080 --directory ~/www --bind 127.0.0.1
```

`--bind 127.0.0.1` limita il server al loopback: raggiungibile solo dal
telefono stesso o tramite un tunnel (vedi sotto), non dalla rete locale.
Per renderlo raggiungibile anche in LAN, ometti `--bind` (o usa
`--bind 0.0.0.0`).

Per copiare i file dal Mac/PC:

```bash
scp -P 8022 index.html <utente>@<ip-telefono>:~/www/index.html
```

## 4. Tenerlo acceso in background

Chiudendo la sessione SSH, `python -m http.server` lanciato al punto 3 muore.
Per farlo sopravvivere:

```bash
setsid nohup python -m http.server 8080 --directory ~/www --bind 127.0.0.1 \
  < /dev/null > ~/webserver.log 2>&1 & disown
```

**Il solo `nohup ... &` non basta**: chiudendo la sessione SSH, Termux
termina comunque il processo. Serve `setsid` per staccarlo davvero dalla
sessione, con stdin da `/dev/null`.

## 5. Pubblicarlo su internet con un Cloudflare Tunnel

```bash
pkg install cloudflared
```

### Opzione rapida (URL casuale, per provare)

Nessun login richiesto, ma l'URL cambia a ogni riavvio e non ha garanzie di
uptime:

```bash
cloudflared tunnel --url http://127.0.0.1:8080
```

Il log stampa l'URL pubblico generato, tipo
`https://<parole-casuali>.trycloudflare.com`.

### Opzione stabile (dominio fisso, richiede account Cloudflare)

Un **named tunnel** ha bisogno del login OAuth la prima volta:

```bash
cloudflared tunnel login          # apre un URL da autorizzare nel browser
cloudflared tunnel create <nome-tunnel>
```

Configura `~/.cloudflared/config.yml`:

```yaml
tunnel: <tunnel-id>
credentials-file: /data/data/com.termux/files/home/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: tuo-sottodominio.tuodominio.org
    service: http://127.0.0.1:8080
  - service: http_status:404
```

Poi collega il DNS e avvia:

```bash
cloudflared tunnel route dns <nome-tunnel> tuo-sottodominio.tuodominio.org

setsid nohup cloudflared tunnel run <nome-tunnel> \
  < /dev/null > ~/cloudflared.log 2>&1 & disown
```

`cloudflared tunnel login` richiede un browser interattivo: se lo fai da SSH
senza schermo, apri l'URL stampato a schermo su un altro dispositivo già
loggato all'account Cloudflare che vuoi usare.

## 6. Tenere Termux vivo a schermo spento

Android sospende le app in background per risparmiare batteria. Per un
server che deve restare su:

```bash
termux-wake-lock
```

Mantiene sveglia la CPU anche a schermo spento (non il display, quindi
consuma meno che tenerlo acceso).

Sul telefono, disattiva anche le restrizioni batteria per Termux:

```text
Impostazioni -> App -> Termux -> Batteria -> Nessuna restrizione
Impostazioni -> App -> Termux -> Avvio automatico (se presente, es. MIUI)
```

Senza questo, produttori come Xiaomi/MIUI possono terminare Termux in
background anche con `termux-wake-lock` attivo.

## 7. Avvio automatico al riavvio del telefono

Dalla versione `2024.10.24` di Termux in poi (Play Store compresa), qualunque
script eseguibile in `~/.termux/boot/` viene lanciato automaticamente da
Android al riavvio — funzione prima offerta dall'app separata Termux:Boot,
ora integrata.

```bash
mkdir -p ~/.termux/boot
cat > ~/.termux/boot/start-services <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
sshd
setsid nohup python -m http.server 8080 --directory ~/www --bind 127.0.0.1 \
  < /dev/null > ~/webserver.log 2>&1 & disown
setsid nohup cloudflared tunnel run <nome-tunnel> \
  < /dev/null > ~/cloudflared.log 2>&1 & disown
EOF
chmod +x ~/.termux/boot/start-services
```

Perché lo script parta davvero, va tenuto abilitato il permesso "Avvio
automatico" del punto 6 — senza, Android non consegna il broadcast di boot
a Termux (comune su MIUI/Xiaomi).

## Cheat sheet comandi utili

| Comando | Cosa fa |
|---|---|
| `sshd` | avvia il server SSH sulla porta 8022 |
| `pgrep sshd` | verifica se sshd è attivo |
| `pkill sshd` | ferma sshd |
| `termux-wake-lock` | CPU sveglia a schermo spento |
| `termux-wake-unlock` | rilascia il wake lock |
| `python -m http.server 8080 --directory ~/www --bind 127.0.0.1` | server web sulla porta 8080 |
| `setsid nohup <comando> < /dev/null > log.txt 2>&1 & disown` | esegue `<comando>` in background, sopravvive alla chiusura della sessione SSH |
| `cloudflared tunnel --url http://127.0.0.1:8080` | tunnel pubblico rapido, URL casuale |
| `cloudflared tunnel list` | elenca i tunnel già creati sull'account |
| `pgrep -laf "http.server\|cloudflared\|sshd"` | controlla quali servizi sono attivi |
| `scp -P 8022 file <utente>@<ip>:~/percorso` | copia un file dal Mac/PC al telefono |
| `ssh -p 8022 <utente>@<ip>` | connessione SSH al telefono |

## Limiti da tenere a mente

- **Non è un server 24/7 affidabile come hardware dedicato.** Un telefono
  Android può essere ucciso in background dal sistema nonostante wake-lock e
  permessi, specie su MIUI/Xiaomi. Per servizi importanti, meglio un
  Raspberry Pi o un mini PC.
- **Android 15+ blocca `ip addr`/`ifconfig` a Termux** (SELinux nega
  l'accesso netlink): l'IP locale va letto dalle impostazioni Android, non da
  riga di comando.
- **`/tmp` non esiste in Termux**: usare `$TMPDIR` (`$PREFIX/tmp`) per file
  temporanei.
- **DHCP cambia l'IP locale nel tempo**: per un accesso stabile via SSH senza
  ricercare l'IP ogni volta, usare Tailscale (IP stabile indipendente dal
  Wi-Fi) o assegnare un IP fisso nel router.
