// Minimal SPA logic. Works behind path-based Ingress.
// Calls /api/* (Ingress maps /<clientId>/api → backend service).

import "./style.css";

const $ = (sel) => document.querySelector(sel);
const out = $("#out");
const btnHello = $("#btnHello");
const btnEcho = $("#btnEcho");

btnHello.addEventListener("click", async () => {
  out.textContent = "Requesting /api/hello…";
  try {
    const r = await fetch("/api/hello");
    const j = await r.json();
    out.textContent = JSON.stringify(j, null, 2);
  } catch (e) {
    out.textContent = String(e.message || e);
  }
});

btnEcho.addEventListener("click", async () => {
  out.textContent = "POST /api/echo…";
  try {
    const r = await fetch("/api/echo", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ client: true, t: Date.now() })
    });
    const j = await r.json();
    out.textContent = JSON.stringify(j, null, 2);
  } catch (e) {
    out.textContent = String(e.message || e);
  }
});
