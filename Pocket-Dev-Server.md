# Pocket Dev Server

> Documento di visione e architettura.
> Revisione del draft iniziale con vincoli tecnici reali di Android/Termux,
> sezione sicurezza e roadmap a fasi.

---

## Visione

**Pocket Dev Server** è una dashboard web che trasforma uno smartphone Android
con **Termux** in un piccolo server Linux portatile.

L'obiettivo è offrire un'interfaccia grafica semplice ma potente per gestire
progetti, servizi, file e strumenti di sviluppo direttamente dal browser,
evitando di lavorare esclusivamente dal terminale.

Il valore del progetto non è "un terminale nel browser" — ne esistono molti — ma
**il pannello di controllo del proprio telefono-server**: un dispositivo
riciclato che resta acceso, sempre raggiungibile, e che si amministra da
qualsiasi altro schermo di casa.

## Obiettivi

- Rendere Termux accessibile anche tramite GUI.
- Gestire più progetti contemporaneamente.
- Amministrare servizi locali e remoti.
- Offrire un ambiente di sviluppo sempre disponibile.
- Integrare le funzionalità native di Android tramite Termux:API.

## Vincoli di progetto

Questi non sono dettagli implementativi: sono requisiti che decidono se il
progetto è utilizzabile o no.

1. **Sicuro per default.** Il pannello esegue comandi arbitrari. Non deve mai
   essere raggiungibile senza autenticazione. Vedi [Sicurezza](#sicurezza).
2. **Leggero.** Il pannello non deve mangiarsi le risorse che dovrebbe mettere a
   disposizione dei progetti ospitati. Budget indicativo: **< 100 MB di RAM** a
   riposo per backend + frontend.
3. **Sopravvive ad Android.** Doze mode, ottimizzazione batteria e OOM killer
   sono il motivo numero uno per cui questi progetti smettono di funzionare dopo
   due giorni. Vedi [Sopravvivenza su Android](#sopravvivenza-su-android).
4. **Ogni azione è un endpoint HTTP documentato.** Nessuna logica solo lato
   frontend. È la condizione che rende possibili automazioni e AI assistant più
   avanti, senza riscrivere niente.

---

# Sicurezza

Il pannello espone, in un unico servizio: esecuzione di comandi arbitrari, un
file manager con upload, e accesso ai repository git. Senza autenticazione non è
un dev server, è una shell remota aperta a chiunque si trovi sulla stessa rete
Wi-Fi.

**Requisiti non negoziabili:**

- **Bind su `127.0.0.1` di default.** L'ascolto su `0.0.0.0` è una scelta
  esplicita dell'utente, non il comportamento predefinito.
- **Autenticazione obbligatoria.** Token o password, richiesta anche in LAN. Il
  servizio non deve poter partire senza una credenziale configurata.
- **Nessuna porta aperta sul router.** L'accesso da fuori casa passa
  esclusivamente per un tunnel (Cloudflare Tunnel, Tailscale). Il port
  forwarding non è una modalità supportata.
- **HTTPS** quando l'accesso non è su loopback.
- **Sessioni con scadenza** e revoca dei token.
- **Log degli accessi e dei comandi eseguiti**, consultabili dal pannello.

Il terminale web e il file manager sono, di fatto, privilegi pieni sull'account
Termux: vanno trattati con la stessa serietà di una chiave SSH.

---

# Sopravvivenza su Android

Perché il server sia davvero "sempre disponibile" servono, oltre a Termux:Boot:

- **Wakelock di Termux** attivo (`termux-wake-lock`), altrimenti il processo
  viene sospeso a schermo spento.
- **Esclusione dall'ottimizzazione batteria** per Termux e Termux:Boot, dalle
  impostazioni Android.
- **Avvio automatico al boot** tramite Termux:Boot (script già presente:
  [boot-start-services.sh](boot-start-services.sh)).
- **Riavvio automatico dei servizi** dopo un OOM kill, con backoff.
- **Consumo contenuto**: polling delle metriche a intervalli ragionevoli
  (secondi, non decimi di secondo), WebSocket unico e condiviso invece di
  polling HTTP ripetuto.

Vale la pena documentare anche il comportamento atteso a batteria scarica: sotto
una certa soglia il pannello dovrebbe ridurre la frequenza di aggiornamento
invece di continuare come se nulla fosse.

---

# Funzionalità

## Dashboard

Visualizzazione in tempo reale di:

- CPU
- RAM
- Batteria
- Temperatura
- Memoria disponibile
- Uptime
- Connessione di rete
- Indirizzi IP
- Stato dei servizi

Base di partenza già presente: [sysinfo.sh](sysinfo.sh).

## Gestione Processi

- Avvio
- Arresto
- Riavvio
- Log live
- Utilizzo CPU e memoria
- Auto-restart

**Decisione architetturale da prendere prima di scrivere codice:** o la
dashboard è un frontend per **PM2** (e allora auto-restart, log e persistenza
sono responsabilità di PM2, il pannello li legge e basta), oppure si scrive un
supervisor proprio e **PM2 esce dall'architettura**. Avere entrambi significa
non sapere mai chi possiede un processo.

Raccomandazione: PM2 in v1, perché risolve già auto-restart, log rotation e
ripristino al boot senza scrivere niente. Un supervisor proprio si valuta solo
se PM2 si rivela troppo pesante sul device.

## File Manager

- Editor di testo integrato
- Upload e download
- Ricerca
- Anteprima immagini e PDF
- Drag & Drop

**Sull'editor:** Monaco (il motore di VS Code) pesa alcuni MB e presuppone mouse
e tastiera fisica; su touch l'esperienza di editing è scadente. Su un telefono
riciclato — cioè esattamente il caso d'uso del progetto — è la scelta sbagliata.
**CodeMirror 6** copre il 90% delle esigenze con una frazione del peso ed è
progettato per il touch.

## Terminale

- Più terminali contemporanei
- Temi
- Cronologia
- Scorciatoie da tastiera

## Git

- Commit
- Push
- Pull
- Branch
- Diff
- Cronologia

## Gestione Progetti

Ogni cartella viene riconosciuta come progetto.

Esempio:

``` text
🌍 Astri
▶ Avvia
⟳ Riavvia
📜 Log
🌐 Apri

📚 Librario
▶ Build
▶ Deploy

🤖 Telegram Bot
▶ Avvia
📈 Stato
```

## One Click Apps

Il sistema riconosce automaticamente il tipo di progetto.

### Node.js

- npm install
- npm run dev
- npm test

### Python

- pip install
- uvicorn
- flask
- fastapi

### Static Site

- Anteprima
- Build
- Deploy

### Docker — non disponibile in locale

**Docker non può girare su Termux.** Richiede privilegi di root e feature del
kernel (namespaces, cgroups) che Android non espone. `docker compose up` come
comando locale è irrealizzabile e va tolto dalle One Click Apps.

Resta invece sensato il **controllo di un Docker remoto** (Raspberry Pi, NAS,
VPS) via API: quella è un'integrazione, non una funzionalità locale. Vedi
[Possibili Integrazioni](#possibili-integrazioni).

## Android Integration

Grazie a Termux:API:

- Notifiche
- Clipboard
- Vibrazione
- Text-to-Speech
- Speech-to-Text
- Condivisione file
- GPS, fotocamera, sensori

**Nota di scope:** notifiche, clipboard e condivisione file servono direttamente
il caso d'uso "amministro il mio server" — le notifiche in particolare sono
preziose (servizio caduto, build finita, batteria bassa). Fotocamera, GPS e
sensori sono divertenti ma ortogonali all'idea di dev server: vanno tenuti fuori
dal nucleo e trattati come plugin opzionali, per non far crescere il progetto in
direzioni che non servono. Materiale già presente in questa direzione:
[camera.html](camera.html), [camera-loop.sh](camera-loop.sh).

## AI Assistant

Un assistente integrato capace di comprendere richieste come:

- "Riavvia il server Fastify."
- "Mostrami gli errori degli ultimi 10 minuti."
- "Perché il container è fermo?"
- "Esegui git pull e riavvia il progetto."

**Collocazione nella roadmap:** è la feature più interessante ed è anche quella
che dipende da tutto il resto. Va affrontata **per ultima**. Se si rispetta il
vincolo "ogni azione è un endpoint HTTP documentato", l'assistente si riduce a
esporre quegli endpoint come tool e arriva quasi gratis. Se lo si affronta
presto, lo si scrive due volte.

## Possibili Integrazioni

- Docker remoto (via API)
- Raspberry Pi
- Home Assistant
- MQTT
- ESP32
- Cloudflare Tunnel
- Tailscale
- GitHub

---

# Architettura Tecnica

## Backend

- Node.js + Fastify
- WebSocket (canale unico condiviso per le metriche live)
- SQLite per la configurazione e lo storico
- PM2 come supervisor dei processi progetto

## Frontend

- HTML
- Bootstrap
- JavaScript
- CodeMirror 6 come editor

## Android

- Termux
- Termux:API
- Termux:Boot

---

# Roadmap

Il draft iniziale metteva sullo stesso piano dashboard, terminale, git, AI, GPS,
fotocamera, MQTT ed ESP32. Così non è pianificabile. Questa è la scomposizione
proposta.

## v1 — il nucleo minimo

Delimitata, e da usare davvero per qualche settimana prima di aggiungere altro.

- Autenticazione (token) e bind su loopback per default
- Dashboard sysinfo in tempo reale
- Elenco progetti (una cartella = un progetto)
- Avvio / arresto / riavvio di un progetto
- Log live
- Avvio automatico al boot, con wakelock

Al termine della v1 il progetto deve essere già utile da solo. Se non lo è, il
problema non si risolve aggiungendo feature.

## v2 — lavorare dal pannello

- File manager con editor CodeMirror
- Terminale web
- Git: stato, commit, pull, push
- Notifiche Android sugli eventi (servizio caduto, build finita)

## v3 — automazione

- One Click Apps per tipo di progetto rilevato
- Accesso da remoto via tunnel
- Integrazioni esterne (Docker remoto, MQTT, Home Assistant)

## v4 — assistente

- AI Assistant sopra gli endpoint già esistenti

---

# Filosofia

Pocket Dev Server vuole essere il pannello di controllo personale di uno
sviluppatore, capace di trasformare uno smartphone inutilizzato in un server
Linux sempre disponibile.

Più che un semplice terminale web, punta a diventare un ecosistema per sviluppo,
automazione e amministrazione, con un'interfaccia moderna e modulare — ma con la
disciplina di restare leggero, sicuro e realmente sempre acceso, che sono le tre
cose che decidono se un progetto del genere viene usato o abbandonato.

---

## Documenti collegati

- [come-hostare-una-pagina-con-termux.md](come-hostare-una-pagina-con-termux.md) — guida pratica al primo server statico
- [Termolux-android.md](Termolux-android.md) — appunti generali su Termux
- [boot-start-services.sh](boot-start-services.sh) — avvio dei servizi al boot
- [sysinfo.sh](sysinfo.sh) — metriche di sistema, base per la dashboard
