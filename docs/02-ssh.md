# 2. SSH senza complicazioni

SSH serve per amministrare Termux dal Mac/PC. Non è necessario per il traffico
pubblico del sito: Cloudflare Tunnel funziona con una connessione uscente.

## Prima connessione

In Termux:

```bash
passwd
sshd
whoami
```

La porta SSH di Termux è `8022`.

Dal computer, copia la chiave pubblica una sola volta:

```bash
ssh-copy-id -p 8022 -i ~/.ssh/id_ed25519.pub <utente>@<ip-del-telefono>
```

## Alias SSH

In `~/.ssh/config` sul computer:

```sshconfig
Host termux-phone
    HostName <ip-lan-o-tailscale-del-telefono>
    Port 8022
    User <utente-termux>
    IdentityFile ~/.ssh/id_ed25519
```

Da quel momento:

```bash
ssh termux-phone
```

Compila `config.env` partendo da [`config.example.env`](../config.example.env)
e usa gli obiettivi del `Makefile` per evitare di riscrivere ogni volta host,
utente e porta.
