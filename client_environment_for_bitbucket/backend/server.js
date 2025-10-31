// Minimal API for all clients. Same image reused per client.
// Exposes /health and /api/* endpoints.

import express from "express";
import dotenv from "dotenv";

dotenv.config();

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;

// simple health for k8s probes
app.get("/health", (_req, res) => res.json({ ok: true, service: "api" }));

// demo endpoints
app.get("/api/hello", (_req, res) => {
  res.json({ ok: true, message: "Hello from API 👋", time: new Date().toISOString() });
});

app.post("/api/echo", (req, res) => {
  res.json({ ok: true, received: req.body ?? null, time: new Date().toISOString() });
});

const srv = app.listen(PORT, () => {
  console.log(`[api] listening on 0.0.0.0:${PORT}`);
});

// graceful shutdown for k8s
const shutdown = (sig) => () => {
  console.log(`[api] ${sig} received`);
  srv.close(() => {
    console.log("[api] server closed");
    process.exit(0);
  });
};
process.on("SIGTERM", shutdown("SIGTERM"));
process.on("SIGINT", shutdown("SIGINT"));
