// server.js
import express from "express";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";
import * as hc from "./hetzner.js";
import { exec } from "child_process"; // Import exec for running scripts

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const {
  PORT = 3000,
  PANEL_USER = "admin",
  PANEL_PASS = "admin",
} = process.env;

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// --- Existing Authentication Middleware (Unchanged) ---
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

app.use(express.static(path.join(__dirname, "public")));

// --- Existing Hetzner API Endpoints (Unchanged) ---
app.get("/api/list", async (_req, res) => {
  try { res.json({ ok: true, servers: await hc.listServers() }); }
  catch (e) { res.status(500).json({ error: String(e.message || e) }); }
});

app.post("/api/servers", async (req, res) => {
  try { res.status(201).json({ ok: true, server: (await hc.createServer(req.body || {})) }); }
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
  } catch (e) { res.status(500).json({ error: String(e.message || e) }); }
});


// --- NEW: API Endpoint for Creating Kubernetes Clients ---
// This new section is added without affecting the code above.
// Replace the existing /api/create-client endpoint with this one
app.post("/api/create-client", (req, res) => {
  const { clientName } = req.body;

  if (!clientName) {
    return res.status(400).json({ error: "Client name is required" });
  }

  const { exec } = require("child_process");
  const path = require("path");

  const scriptPath = path.join(process.cwd(), "..", "basic-blog", "k8s", "new-client.ps1");
  
  // Added -NoProfile and more robust path handling
  const command = `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${scriptPath}" -ClientId ${clientName}`;

  console.log(`--- Attempting to execute command ---`);
  console.log(command);
  console.log(`Script path exists: ${require('fs').existsSync(scriptPath)}`);
  
  const child = exec(command);

  child.stdout.on('data', (data) => {
    console.log(`stdout: ${data}`);
  });

  child.stderr.on('data', (data) => {
    console.error(`stderr: ${data}`);
  });

  child.on('close', (code) => {
    console.log(`child process exited with code ${code}`);
    if (code !== 0) {
      return res.status(500).json({ message: 'Script execution failed.' });
    }
    res.status(201).json({ message: `Client '${clientName}' creation process finished.` });
  });

  child.on('error', (err) => {
    console.error('Failed to start subprocess.', err);
    return res.status(500).json({ message: 'Failed to start script subprocess.' });
  });
});


// --- Existing Server Start (Unchanged) ---
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));