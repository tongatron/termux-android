# 5. Troubleshooting

## Controllo dal computer

```bash
make status
make logs
```

Oppure direttamente dal telefono:

```bash
pgrep -laf 'sshd|http.server|cloudflared|sysinfo'
curl -I http://127.0.0.1:8080/
tail -n 100 ~/cloudflared-termux.log
```

## Sintomi comuni

| Sintomo | Causa più probabile | Azione |
| --- | --- | --- |
| `HTTP 530`, `error code: 1033` | nessun `cloudflared` connesso a Cloudflare | apri Termux e rilancia lo script di boot |
| `HTTP 502` | tunnel attivo, origine locale non disponibile | controlla `python -m http.server` |
| `connection refused` su `8022` | Termux/`sshd` fermo o telefono offline | apri Termux, avvia `sshd`, verifica rete |
| deploy con `Permission denied` | chiave SSH o `authorized_keys` errati | ripeti la configurazione SSH |
| servizio morto dopo qualche ora | Android/MIUI ha chiuso Termux | abilita autostart e batteria senza restrizioni |

## Check finale

```bash
make deploy
make status
curl -I https://termux.tongatron.org/
```

Per un sito importante, sposta il frontend su Cloudflare Pages, GitHub Pages,
Raspberry Pi o VPS e usa Termux come laboratorio o origine temporanea.
