import express from "express";
import dotenv from "dotenv";
dotenv.config();

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;

// Healthcheck
app.get("/health", (_req, res) => res.json({ ok: true, service: "api" }));

// Simple echo endpoint
app.post("/api/echo", (req, res) => {
  res.json({ ok: true, you_sent: req.body || null, ts: new Date().toISOString() });
});

// Example: GET /api/time
app.get("/api/time", (_req, res) => {
  res.json({ ok: true, now: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`API listening on http://0.0.0.0:${PORT}`);
});
