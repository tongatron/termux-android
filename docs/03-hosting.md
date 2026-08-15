# 3. Hosting with Cloudflare Tunnel

## Temporary URL

For a quick test:

```bash
cloudflared tunnel --url http://127.0.0.1:8080
```

The `trycloudflare.com` URL is random and changes. Do not use it as a
permanent address.

## Stable domain

A named tunnel connects a hostname to `127.0.0.1:8080`:

```yaml
tunnel: <tunnel-id>
credentials-file: /data/data/com.termux/files/home/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: example.yourdomain.com
    service: http://127.0.0.1:8080
  - service: http_status:404
```

Connect DNS and start the tunnel:

```bash
cloudflared tunnel route dns <tunnel-name> example.yourdomain.com
cloudflared tunnel run <tunnel-name>
```

Tunnel credentials stay on the phone and are excluded from the repository by
`.gitignore`.

## Deploy from the computer

```bash
cp config.example.env config.env
# edit config.env with the host, username, and SSH port
make check
make deploy
```

The deploy script creates the site directories and copies the pages used by the
demo (`/`, `/guida/`, and `/camera/`).
