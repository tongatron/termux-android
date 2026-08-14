# 3. Hosting con Cloudflare Tunnel

## URL temporaneo

Per una prova al volo:

```bash
cloudflared tunnel --url http://127.0.0.1:8080
```

L'URL `trycloudflare.com` è casuale e cambia. Non usarlo come indirizzo
permanente.

## Dominio stabile

Un named tunnel collega un hostname a `127.0.0.1:8080`:

```yaml
tunnel: <tunnel-id>
credentials-file: /data/data/com.termux/files/home/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: esempio.tuodominio.it
    service: http://127.0.0.1:8080
  - service: http_status:404
```

Avvio:

```bash
cloudflared tunnel route dns <nome-tunnel> esempio.tuodominio.it
cloudflared tunnel run <nome-tunnel>
```

Il file JSON del tunnel e ogni certificato restano soltanto sul telefono e
sono esclusi dal repository tramite `.gitignore`.

## Deploy dal computer

```bash
cp config.example.env config.env
# modifica config.env con host, utente e porta SSH
make check
make deploy
```

Il deploy crea le directory del sito e copia le pagine nelle posizioni usate
dalla demo (`/`, `/guida/`, `/camera/`).
