# Pocket Dev Server

> Vision and architecture document.
> Revised from the initial draft with real Android/Termux constraints,
> security requirements, and a phased roadmap.

---

## Vision

**Pocket Dev Server** is a web dashboard that turns an Android smartphone with
**Termux** into a small, portable Linux server.

The goal is a simple but powerful browser interface for managing projects,
services, files, and development tools directly on the phone, without relying
exclusively on a terminal.

The value is not “a terminal in the browser” — many of those already exist —
but **a control panel for your own phone-server**: a recycled device that stays
available and can be administered from any other screen at home.

## Goals

- Make Termux accessible through a GUI.
- Manage multiple projects at the same time.
- Administer local and remote services.
- Provide an always-available development environment.
- Integrate native Android capabilities through Termux:API.

## Project constraints

These are not implementation details. They determine whether the project is
actually usable.

1. **Secure by default.** The dashboard executes arbitrary commands. It must
   never be reachable without authentication. See [Security](#security).
2. **Lightweight.** The dashboard must not consume the resources intended for
   hosted projects. Indicative budget: **less than 100 MB of idle RAM** for
   backend plus frontend.
3. **Survive Android.** Doze mode, battery optimization, and the OOM killer are
   the main reasons these projects stop working after two days. See [Surviving
   Android](#surviving-android).
4. **Every action is a documented HTTP endpoint.** No frontend-only logic. This
   enables automation and future AI assistants without a rewrite.

---

# Security

The dashboard exposes arbitrary command execution, a file manager with upload,
and Git repository access in one service. Without authentication it is not a
development server; it is a remote shell open to anyone on the same Wi-Fi.

**Non-negotiable requirements:**

- **Bind to `127.0.0.1` by default.** Listening on `0.0.0.0` must be an explicit
  user choice, never the default.
- **Authentication is mandatory.** Use a token or password, including on the
  LAN. The service must not start without configured credentials.
- **No router port forwarding.** Remote access must use a tunnel (Cloudflare
  Tunnel or Tailscale). Port forwarding is not a supported mode.
- **HTTPS** whenever access is not loopback-only.
- **Expiring sessions** and token revocation.
- **Access and command logs** visible in the dashboard.

The web terminal and file manager effectively provide full privileges for the
Termux account. Treat them with the same care as an SSH key.

---

# Surviving Android

For a server to be genuinely “always available”, Termux:Boot alone is not
enough:

- **Termux wake lock** enabled (`termux-wake-lock`), otherwise the process may
  be suspended when the screen is off;
- **battery optimization excluded** for Termux and Termux:Boot in Android
  settings;
- **automatic boot startup** through Termux:Boot (the ready-to-use script is
  [`boot-start-services.sh`](boot-start-services.sh));
- **automatic service restart** after an OOM kill, with backoff;
- **low overhead**: poll metrics at sensible intervals (seconds, not tenths of
  a second) and use one shared WebSocket instead of repeated HTTP polling.

Document the low-battery behavior too: below a threshold, the dashboard should
reduce its refresh rate instead of behaving as if nothing changed.

---

# Features

## Dashboard

Real-time display of:

- CPU
- RAM
- Battery
- Temperature
- Available storage
- Uptime
- Network connection
- IP addresses
- Service status

Existing starting point: [`sysinfo.sh`](sysinfo.sh).

## Process management

- Start
- Stop
- Restart
- Live logs
- CPU and memory usage
- Automatic restart

**Architectural decision required before coding:** either the dashboard is a
frontend for **PM2** — in which case PM2 owns restart, logs, and persistence —
or a custom supervisor is written and **PM2 is removed from the architecture**.
Having both means no one knows which component owns a process.

Recommendation: PM2 for v1, because it already solves automatic restart, log
rotation, and boot recovery. Evaluate a custom supervisor only if PM2 proves too
heavy for the device.

## File manager

- Integrated text editor
- Upload and download
- Search
- Image and PDF preview
- Drag and drop

**Editor choice:** Monaco (the VS Code engine) weighs several megabytes and
assumes a mouse and physical keyboard; on touch, editing is poor. For a reused
phone — exactly this project's use case — it is the wrong choice. **CodeMirror
6** covers most needs at a fraction of the weight and is designed for touch.

## Terminal

- Multiple concurrent terminals
- Themes
- History
- Keyboard shortcuts

## Git

- Commit
- Push
- Pull
- Branch
- Diff
- History

## Project management

Every folder is recognized as a project.

Example:

```text
🌍 Astri
▶ Start
⟳ Restart
📜 Logs
🌐 Open

📚 Librario
▶ Build
▶ Deploy

🤖 Telegram Bot
▶ Start
📈 Status
```

## One-click apps

The system automatically detects the project type.

### Node.js

- npm install
- npm run dev
- npm test

### Python

- pip install
- uvicorn
- flask
- fastapi

### Static site

- Preview
- Build
- Deploy

### Docker — not available locally

**Docker cannot run natively in Termux.** It requires root privileges and
kernel features (namespaces and cgroups) that Android does not expose.
`docker compose up` as a local command is not realistic and should be removed
from the one-click apps.

Controlling a remote Docker host (Raspberry Pi, NAS, or VPS) through an API is
still sensible: that is an integration, not a local feature. See [Possible
integrations](#possible-integrations).

## Android integration

Through Termux:API:

- Notifications
- Clipboard
- Vibration
- Text-to-speech
- Speech-to-text
- File sharing
- GPS, camera, and sensors

**Scope note:** notifications, clipboard, and file sharing directly support the
“administer my server” use case. Notifications are particularly valuable for a
failed service, completed build, or low battery. Camera, GPS, and sensors are
interesting but orthogonal to the development-server idea: keep them out of the
core and treat them as optional plugins. Existing material in that direction:
[`camera.html`](camera.html), [`camera-loop.sh`](camera-loop.sh).

## AI assistant

An integrated assistant could understand requests such as:

- “Restart the Fastify server.”
- “Show me the errors from the last 10 minutes.”
- “Why is the container stopped?”
- “Run git pull and restart the project.”

**Roadmap position:** this is the most interesting feature and also the one
that depends on everything else. It should come **last**. If every action is a
documented HTTP endpoint, the assistant only needs to expose those endpoints as
tools and arrives almost for free. Building it early means building it twice.

## Possible integrations

- Remote Docker (API)
- Raspberry Pi
- Home Assistant
- MQTT
- ESP32
- Cloudflare Tunnel
- Tailscale
- GitHub

---

# Technical architecture

## Backend

- Node.js + Fastify
- WebSocket (one shared channel for live metrics)
- SQLite for configuration and history
- PM2 as the project process supervisor

## Frontend

- HTML
- Bootstrap
- JavaScript
- CodeMirror 6 as the editor

## Android

- Termux
- Termux:API
- Termux:Boot

---

# Roadmap

The initial draft treated the dashboard, terminal, Git, AI, GPS, camera, MQTT,
and ESP32 as equal priorities. That is not plan­ning. The proposed breakdown is:

## v1 — the minimum core

Small enough to use for several weeks before adding anything else.

- Token authentication and loopback binding by default
- Real-time sysinfo dashboard
- Project list (one folder = one project)
- Start / stop / restart a project
- Live logs
- Boot startup with a wake lock

At the end of v1, the project must already be useful on its own. If it is not,
adding features will not solve the problem.

## v2 — work from the dashboard

- File manager with a CodeMirror editor
- Web terminal
- Git: status, commit, pull, push
- Android notifications for events (service down, build complete)

## v3 — automation

- One-click apps for detected project types
- Remote access through a tunnel
- External integrations (remote Docker, MQTT, Home Assistant)

## v4 — assistant

- AI assistant on top of the existing endpoints

---

# Philosophy

Pocket Dev Server aims to be a developer's personal control panel, turning an
unused smartphone into an always-available Linux server.

More than a simple web terminal, it should become an ecosystem for development,
automation, and administration, with a modern modular interface — while
remaining lightweight, secure, and genuinely available. Those are the three
properties that determine whether a project like this gets used or abandoned.

---

## Related documents

- [README.md](README.md) — public overview and quick start
- [docs/01-installazione.md](docs/01-installazione.md) — installation guide
- [boot-start-services.sh](boot-start-services.sh) — boot service launcher
- [sysinfo.sh](sysinfo.sh) — system metrics, the dashboard starting point
