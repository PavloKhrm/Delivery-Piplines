import express from "express";
import dotenv from "dotenv";
dotenv.config();

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;

app.get("/health", (_req, res) => res.json({ ok: true, service: "api" }));

app.get("/api/time", (_req, res) => {
  res.json({ ok: true, now: new Date().toISOString() });
});

app.post("/api/echo", (req, res) => {
  res.json({ ok: true, you_sent: req.body ?? null });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`API listening on http://0.0.0.0:${PORT}`);
});
