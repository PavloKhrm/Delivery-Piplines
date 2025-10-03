# Delivery-Piplines

Create/delete Hetzner Cloud VPS via a tiny web UI. Each server gets its own auto-generated OpenSSH key pair.

## Requirements

* Node.js **≥18**
* `ssh-keygen` available on PATH (macOS/Linux: built-in; Windows: install OpenSSH)

## Setup

```bash
git clone <your-repo>
cd hetzner-dashboard
npm i
cp .env.example .env
```

Edit **.env**:

```
HCLOUD_TOKEN=<your Hetzner Cloud API token (Read & Write)>
PANEL_USER=admin
PANEL_PASS=admin
PORT=3000
```

## Run

```bash
npm start
```

Open: `http://localhost:3000`
Login with **PANEL_USER / PANEL_PASS**.

## Use

1. Select **Type**, **Location**, **Image** (loaded from Hetzner API).
2. Enter **Client** (or pick existing from suggestions).
3. Click **Create**.

   * A fresh SSH key pair is generated and saved to `./keys/`.
   * The public key is uploaded to Hetzner; a server is created.
4. In **Servers** list:

   * Expand a card to see specs, location, pricing, key file name.
   * **Show key** reveals the private key (also saved on disk).
   * **Delete** removes the server and its record from the local DB.

## Project structure

```
server.js        # thin Express server (routes + static)
hetzner.js       # Hetzner API + local JSON “DB”
ssh.js           # OpenSSH key generation via ssh-keygen
public/          # front-end (index.html, styles.css, app.js)
data/servers.json# local records (auto-created)
keys/            # private keys (auto-created, 0600 perms)
```

## Notes

* Private keys and `data/` are **gitignored** by default.
* If you see `422` on `/ssh_keys`, ensure keys are generated with `ssh-keygen` (OpenSSH format).
* Pricing/specs are fetched live; amounts are formatted client-side.