# 2. SSH without the friction

SSH is used to administer Termux from a Mac/PC. It is not required for public
web traffic: Cloudflare Tunnel uses an outbound connection.

## First connection

In Termux:

```bash
pkg update
pkg install openssh
passwd
sshd
whoami
```

Termux uses SSH port `8022`.

Find the phone IP in Android Wi-Fi settings or in the Tailscale app. Tailscale
is optional: it helps administer the phone, but it does not publish the site.

From the computer, try the first login with the temporary password:

```bash
ssh -p 8022 <termux-user>@<phone-ip>
```

## SSH key

On the computer, create a key if necessary and install it on the phone:

```bash
test -f ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub | \
  ssh -p 8022 <termux-user>@<phone-ip> \
  'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys'
```

## SSH alias

Add this to `~/.ssh/config` on the computer:

```sshconfig
Host termux-phone
    HostName <phone-lan-or-tailscale-ip>
    Port 8022
    User <termux-user>
    IdentityFile ~/.ssh/id_ed25519
```

Then connect with:

```bash
ssh termux-phone
```

Quickly verify the identity and working directory:

```bash
ssh termux-phone 'whoami && hostname && pwd'
```

Fill in `config.env` from [`config.example.env`](../config.example.env) and use
the `Makefile` targets to avoid repeating the host, username, and port.
