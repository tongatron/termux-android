# Termux Android Lab

Un esperimento pubblico: usare uno smartphone Android come piccolo server web,
servire un sito statico da Termux e pubblicarlo su Internet con un dominio vero.

## Demo pubblica

**Sito:** [termux.tongatron.org](https://termux.tongatron.org/)

La demo è servita da un Redmi 12. La pagina mostra lo stato del dispositivo e
dei servizi, ma il principio è generale: al posto di questa pagina puoi
pubblicare un portfolio, una documentazione, una dashboard o un sito statico.

> Questo è un laboratorio didattico, non un hosting professionale. Android può
> sospendere o terminare Termux, la rete mobile può cambiare e il telefono può
> essere spento.

## L'idea in una riga

```text
Browser → Cloudflare → Cloudflare Tunnel → cloudflared su Android
                                      → 127.0.0.1:8080
                                      → Python http.server → ~/www
```

Il tunnel apre una connessione **in uscita** verso Cloudflare: non servono
port-forwarding sul router, IP pubblico statico o Tailscale. Tailscale è utile
solo per amministrare il telefono da remoto.

## Cosa c'è in questo progetto

| File | Scopo |
| --- | --- |
| [`index.html`](index.html) | pagina principale della demo |
| [`guida.html`](guida.html) | guida web consultabile dal sito |
| [`boot-start-services.sh`](boot-start-services.sh) | avvio dei servizi dopo il boot |
| [`sysinfo.sh`](sysinfo.sh) | genera i dati di stato del dispositivo |
| [`camera.html`](camera.html) | pagina opzionale per il modulo fotocamera |
| [`come-hostare-una-pagina-con-termux.md`](come-hostare-una-pagina-con-termux.md) | procedura passo-passo |
| [`Pocket-Dev-Server.md`](Pocket-Dev-Server.md) | appunti sul telefono come server tascabile |

Le note operative con indirizzi e dettagli della rete locale restano escluse
dal repository pubblico.

## Workflow consigliato

La repo è organizzata per separare il “cosa” dal “come”:

| Percorso | Contenuto |
| --- | --- |
| [`docs/`](docs/) | how-to diviso per installazione, SSH, hosting, autostart e diagnosi |
| [`scripts/`](scripts/) | comandi ripetibili per bootstrap, deploy, stato, log e restart |
| [`config.example.env`](config.example.env) | configurazione SSH da copiare in `config.env` |
| [`Makefile`](Makefile) | interfaccia breve per usare gli script dal computer |

Dal Mac/PC il ciclo quotidiano diventa:

```bash
cp config.example.env config.env   # una sola volta: inserisci host e utente
make check                          # controlla gli script
make deploy                         # pubblica il sito su Termux
make status                         # verifica i servizi
make logs                           # legge il log del tunnel
```

Per il percorso completo, parti da [`docs/01-installazione.md`](docs/01-installazione.md).

## Avvio rapido: server locale

In Termux:

```bash
pkg update
pkg install python

mkdir -p ~/www
cp index.html ~/www/
python -m http.server 8080 --directory ~/www --bind 127.0.0.1
```

Il sito è ora disponibile localmente sul telefono:

```bash
curl -I http://127.0.0.1:8080/
```

Il binding su `127.0.0.1` è intenzionale: il server non è esposto direttamente
alla rete locale. Sarà `cloudflared` a fare da unico punto di pubblicazione.

## Pubblicazione con Cloudflare Tunnel

Per una prova veloce si può usare un URL casuale:

```bash
pkg install cloudflared
cloudflared tunnel --url http://127.0.0.1:8080
```

Per un dominio stabile si usa un **named tunnel**. La configurazione minima è:

```yaml
tunnel: <tunnel-id>
credentials-file: /data/data/com.termux/files/home/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: esempio.tuodominio.it
    service: http://127.0.0.1:8080
  - service: http_status:404
```

Poi si collega il DNS e si avvia il tunnel:

```bash
cloudflared tunnel route dns <nome-tunnel> esempio.tuodominio.it
cloudflared tunnel run <nome-tunnel>
```

Le credenziali del tunnel sono private: non vanno committate, pubblicate o
inserite nei log dell'articolo.

## Avvio automatico dopo il riavvio

Il progetto usa uno script unico che avvia `sshd`, il server Python, il loop di
stato e `cloudflared`:

```bash
mkdir -p ~/.termux/boot
chmod +x ~/.termux/boot/start-services
```

Il file deve essere copiato in `~/.termux/boot/start-services`; il modello è
[`boot-start-services.sh`](boot-start-services.sh).

Su Termux dal Google Play Store la funzione di boot è integrata nell'app
principale. Nelle installazioni F-Droid/GitHub occorre installare l'add-on
[Termux:Boot](https://github.com/termux/termux-boot) e aprirlo una volta.

Su Xiaomi/MIUI sono inoltre indispensabili:

```text
Impostazioni → App → Termux → Avvio automatico
Impostazioni → App → Termux → Batteria → Nessuna restrizione
```

Lo script usa `termux-wake-lock`, ma nessuna impostazione software può
garantire che Android non chiuda Termux. Per servizi importanti è preferibile un
Raspberry Pi, un mini-PC o un VPS.

## Diagnosi rapida

```bash
pgrep -laf 'http.server|cloudflared|sshd|sysinfo'
curl -I http://127.0.0.1:8080/
tail -n 80 ~/cloudflared-termux.log
```

Gli errori più utili da riconoscere:

| Sintomo | Significato probabile |
| --- | --- |
| `HTTP 530`, `error code: 1033` | nessun processo `cloudflared` è connesso a Cloudflare |
| `HTTP 502` | il tunnel è connesso, ma il servizio locale sulla porta 8080 non risponde |
| `connection refused` su SSH | Termux o `sshd` non sono attivi, oppure il telefono è offline |

## Sicurezza e privacy

- tutto ciò che si mette in `~/www` diventa pubblico;
- non pubblicare token, certificati, chiavi SSH o file di log;
- rivedere `info.json` prima di esporre dati sul dispositivo;
- mantenere Termux e i pacchetti aggiornati;
- usare autenticazione davanti alle pagine private;
- disattivare o proteggere eventuali endpoint come la fotocamera.

## Perché farlo?

Per imparare, sperimentare e rendere visibile l'intero percorso di una
pubblicazione web: file statici, processo locale, tunnel, DNS, HTTPS,
autostart e limiti di Android. È un server tascabile che trasforma un vecchio
telefono in un piccolo laboratorio sempre a portata di mano.

Per un sito statico che deve restare online senza dipendere dal telefono, la
scelta più adatta è invece [Cloudflare Pages](https://pages.cloudflare.com/),
GitHub Pages o un server dedicato.

## Licenza e riuso

I file sono pensati come materiale didattico e possono essere adattati al
proprio dispositivo, dominio e provider. Prima di copiare la configurazione,
sostituire tutti i nomi, gli indirizzi e i percorsi specifici dell'installazione
originale.
