const out = document.getElementById("out");
const log = (o) => (out.textContent = JSON.stringify(o, null, 2));

document.getElementById("btn-health").onclick = async () => {
  const r = await fetch("/api/health");
  log(await r.json());
};
document.getElementById("btn-time").onclick = async () => {
  const r = await fetch("/api/time");
  log(await r.json());
};
document.getElementById("btn-echo").onclick = async () => {
  const r = await fetch("/api/echo", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ hello: "world" })
  });
  log(await r.json());
};
