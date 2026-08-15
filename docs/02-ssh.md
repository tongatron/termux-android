# 2. SSH senza complicazioni

SSH serve per amministrare Termux dal Mac/PC. Non è necessario per il traffico
pubblico del sito: Cloudflare Tunnel funziona con una connessione uscente.

## Prima connessione

In Termux:

```bash
pkg update
pkg install openssh
passwd
sshd
whoami
```

La porta SSH di Termux è `8022`.

Trova l'IP del telefono nelle impostazioni Wi-Fi Android oppure nell'app
Tailscale. Tailscale è opzionale: serve per amministrare il dispositivo, non
per pubblicare il sito.

Dal computer, prova il primo accesso con la password temporanea:

```bash
ssh -p 8022 <utente-termux>@<ip-del-telefono>
```

## Chiave SSH

Sul computer, genera una chiave se non esiste e installala sul telefono:

```bash
test -f ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub | \
  ssh -p 8022 <utente-termux>@<ip-del-telefono> \
  'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys'
```

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

Per verificare rapidamente identità e percorso:

```bash
ssh termux-phone 'whoami && hostname && pwd'
```

Compila `config.env` partendo da [`config.example.env`](../config.example.env)
e usa gli obiettivi del `Makefile` per evitare di riscrivere ogni volta host,
utente e porta.
