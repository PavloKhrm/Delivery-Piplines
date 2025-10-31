import { Router } from "express";
import fs from "fs";
import * as hc from "../../lib/hetzner.js";
const r = Router();
r.get("/servers", async (_req, res) => {
  try { res.json({ ok: true, servers: await hc.listServers() }); } catch (e) { res.status(500).json({ ok: false, error: String(e.message || e) }); }
});
r.get("/clusters", async (_req, res) => {
  try { res.json({ ok: true, clusters: hc.listClusters() }); } catch (e) { res.status(500).json({ ok: false, error: String(e.message || e) }); }
});
r.get("/clients", async (_req, res) => {
  try { res.json({ ok: true, clients: hc.listClients() }); } catch (e) { res.status(500).json({ ok: false, error: String(e.message || e) }); }
});
r.post("/server/delete", async (req, res) => {
  try { const id = String(req.body.serverId || ""); if (!id) return res.status(400).json({ ok: false, error: "serverId required" }); await hc.deleteServer(id); res.json({ ok: true, id }); } catch (e) { res.status(500).json({ ok: false, error: String(e.message || e) }); }
});
r.get("/key/:id", async (req, res) => {
  try { const p = hc.getPrivateKeyFileByServerId(String(req.params.id || "")); if (!p) return res.status(404).send("not found"); res.setHeader("Content-Type", "text/plain; charset=utf-8"); res.send(fs.readFileSync(p, "utf8")); } catch { res.status(404).send("not found"); }
});
export default r;
