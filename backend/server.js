// backend/server.js
import express from "express";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";
import { attachSshWs } from "./lib/ws-ssh.js";
import authBasic from "./src/middleware/auth.js";
import metaRouter from "./src/routes/meta.js";
import infraRouter from "./src/routes/infra.js";
import clusterRouter from "./src/routes/cluster.js";
import clientRouter from "./src/routes/client.js";
import webhookRouter from "./src/routes/hook.js";
import { log } from "./lib/log.js";

dotenv.config();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PORT = process.env.PORT || 3000;

const app = express();
app.use(express.json({ limit: "2mb" }));
app.use(express.urlencoded({ extended: true }));

app.use((req, res, next) => {
  const t0 = Date.now();
  res.on("finish", () => {
    log("[http]", { m: req.method, u: req.originalUrl, s: res.statusCode, ms: Date.now() - t0 });
  });
  next();
});

app.use(
  authBasic({ user: process.env.PANEL_USER || "admin", pass: process.env.PANEL_PASS || "admin" })
);

app.use(express.static(path.join(__dirname, "public")));
app.use("/api", metaRouter);
app.use("/api", infraRouter);
app.use("/api", clusterRouter);
app.use("/api", clientRouter);
app.use("/api", webhookRouter);

app.get("/", (_req, res) => res.sendFile(path.join(__dirname, "public", "index.html")));

const srv = app.listen(PORT, () => log("[dashboard] up", { url: `http://localhost:${PORT}` }));
attachSshWs(srv);
