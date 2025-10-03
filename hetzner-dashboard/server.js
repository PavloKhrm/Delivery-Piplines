import express from "express";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";
import * as hc from "./hetzner.js";
import { attachSshWs } from "./ws-ssh.js";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const {
  PORT = 3000,
  PANEL_USER = "admin",
  PANEL_PASS = "admin"
} = process.env;

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use((req, res, next) => {
  const hdr = req.headers.authorization || "";
  if (!hdr.startsWith("Basic ")) return challenge(res);
  const [u, p] = Buffer.from(hdr.split(" ")[1], "base64").toString().split(":");
  if (u === PANEL_USER && p === PANEL_PASS) return next();
  return challenge(res);
});
function challenge(res) {
  res.set("WWW-Authenticate", 'Basic realm="Hetzner Dashboard"');
  return res.status(401).send("Auth required");
}

app.get("/api/list", async (_req, res) => {
  try { res.json({ ok: true, servers: await hc.listServers() }); }
  catch (e) { res.status(500).json({ error: String(e.message || e) }); }
});

app.post("/api/create", async (req, res) => {
  try { res.json({ ok: true, ...(await hc.createServer(req.body || {})) }); }
  catch (e) { res.status(500).json({ error: String(e.message || e) }); }
});

app.post("/api/delete", async (req, res) => {
  try {
    const { serverId } = req.body || {};
    if (!serverId) return res.status(400).json({ error: "serverId required" });
    await hc.deleteServer(serverId);
    res.json({ ok: true, deleted: serverId });
  } catch (e) { res.status(500).json({ error: String(e.message || e) }); }
});

app.get("/api/key/:id", async (req, res) => {
  try {
    const key = await hc.getPrivateKey(req.params.id);
    if (!key) return res.status(404).json({ error: "key not found" });
    res.type("text/plain").send(key);
  } catch (e) { res.status(500).json({ error: String(e.message || e) }); }
});

app.get("/api/meta", async (_req, res) => {
  try {
    const [types, locations, images] = await Promise.all([
      hc.listServerTypes(),
      hc.listLocations(),
      hc.listSystemImages()
    ]);
    res.json({ ok: true, types, locations, images });
  } catch (e) {
    res.status(500).json({ error: String(e.message || e) });
  }
});

app.get("/api/clients", async (_req, res) => {
  try {
    res.json({ ok: true, clients: await hc.listClientsFromLabels() });
  } catch (e) {
    res.status(500).json({ error: String(e.message || e) });
  }
});

app.use(express.static(path.join(__dirname, "public")));

const server = app.listen(PORT, () => {
  console.log(`Dashboard → http://localhost:${PORT}`);
});


attachSshWs({ server, panelUser: PANEL_USER, panelPass: PANEL_PASS });
