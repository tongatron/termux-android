# 5. Troubleshooting

## Check from the computer

```bash
make status
make logs
```

Or directly from the phone:

```bash
pgrep -laf 'sshd|http.server|cloudflared|sysinfo'
curl -I http://127.0.0.1:8080/
tail -n 100 ~/cloudflared-termux.log
```

## Common symptoms

| Symptom | Most likely cause | Action |
| --- | --- | --- |
| `HTTP 530`, `error code: 1033` | no `cloudflared` process connected to Cloudflare | open Termux and run the boot script |
| `HTTP 502` | tunnel is up, local origin is unavailable | check `python -m http.server` |
| `connection refused` on `8022` | Termux/`sshd` is stopped or the phone is offline | open Termux, start `sshd`, check the network |
| deploy returns `Permission denied` | wrong SSH key or `authorized_keys` | repeat the SSH setup |
| service dies after a few hours | Android/MIUI killed Termux | enable autostart and no battery restrictions |

## Final check

```bash
make deploy
make status
curl -I https://termux.tongatron.org/
```

For an important site, move the frontend to Cloudflare Pages, GitHub Pages,
Raspberry Pi, or a VPS and use Termux as a lab or temporary origin.
