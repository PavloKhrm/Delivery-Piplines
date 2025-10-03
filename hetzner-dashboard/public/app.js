const $ = (sel, root = document) => root.querySelector(sel);
const escapeHtml = (s) => String(s).replace(/[&<>"']/g, m => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));

const listEl  = $("#list");
const toastEl = $("#toast");
const formEl  = $("#create-form");
const cardTpl = $("#card-tpl");

const clientInput = $("#client");
const typeSel     = $("#type");
const locSel      = $("#loc");
const imgSel      = $("#image");

const specBox     = $("#spec");
const specCores   = $("#spec-cores");
const specRam     = $("#spec-ram");
const specDisk    = $("#spec-disk");
const specStorage = $("#spec-storage");
const specTraffic = $("#spec-traffic");
const specHourly  = $("#spec-hourly");
const specMonthly = $("#spec-monthly");

let META = { types: [], locations: [], images: [] };
let CURRENT = null; // выбранный сервер для drawer/terminal

Promise.all([loadMeta(), loadClients(), loadList()]).then(() => {
  [typeSel, locSel].forEach(el => el.addEventListener("change", updateSpecBox));
  updateSpecBox();
});

/* ---------- create server ---------- */
formEl.addEventListener("submit", async (e) => {
  e.preventDefault();
  const body = {
    client: clientInput.value.trim(),
    serverType: typeSel.value,
    location: locSel.value,
    image: imgSel.value
  };
  setToast("Creating server…");
  const r = await fetch("/api/create", {
    method: "POST",
    headers: {"Content-Type":"application/json"},
    body: JSON.stringify(body)
  });
  const t = await r.json();
  if (!r.ok) return setToast(t.error || "Create failed", true);
  setToast(`Created: ${t.serverName} (${t.ip || "no IP yet"})`);
  await Promise.all([loadList(), loadClients()]);
});

/* ---------- list + tiles ---------- */
async function loadList() {
  const r = await fetch("/api/list");
  const t = await r.json();
  if (!r.ok) return setToast(t.error || "Load failed", true);

  listEl.innerHTML = "";
  (t.servers || []).forEach(s => {
    const node = cardTpl.content.firstElementChild.cloneNode(true);
    node.dataset.id = s.id;
    node.querySelector(".tile__name").textContent = s.name;
    node.querySelector('[data-k="ip"]').textContent = s.ip || "-";
    node.querySelector('[data-k="typeName"]').textContent = s.typeName || "-";
    node.querySelector('[data-k="location"]').textContent = s.location || "-";
    node.querySelector('[data-k="cores"]').textContent = s.cores ?? "—";
    node.querySelector('[data-k="memory_gb"]').textContent = s.memory_gb ?? "—";
    node.querySelector('[data-k="disk_gb"]').textContent = s.disk_gb ?? "—";
    const badge = node.querySelector(".badge");
    badge.dataset.status = (s.status || "").toLowerCase();
    badge.textContent = s.status || "-";

    node.addEventListener("click", () => openDrawer(s));
    listEl.appendChild(node);
  });

  if (!t.servers?.length) {
    listEl.innerHTML = `<p class="muted">No servers yet. Create your first one above.</p>`;
  }
}

async function loadMeta() {
  const r = await fetch("/api/meta");
  const t = await r.json();
  if (!r.ok) { setToast(t.error || "Failed to load meta", true); return; }
  META = t;

  typeSel.innerHTML = `<option value="" disabled selected>Select type</option>` +
    (t.types || []).map(x =>
      `<option value="${escapeHtml(x.name)}">${escapeHtml(x.name)} (${x.cores} vCPU / ${x.memory_gb} GB)</option>`
    ).join("");

  locSel.innerHTML = `<option value="" disabled selected>Select location</option>` +
    (t.locations || []).map(l =>
      `<option value="${escapeHtml(l.name)}">${escapeHtml(l.name)} — ${escapeHtml(l.city)}, ${escapeHtml(l.country)}</option>`
    ).join("");

  const imgs = (t.images || []).sort((a,b) => (a.name||"").localeCompare(b.name||""));
  const preferred = ["ubuntu-24.04","debian-12","ubuntu-22.04"];
  const pref = imgs.filter(i => preferred.includes(i.name));
  const rest = imgs.filter(i => !preferred.includes(i.name));
  imgSel.innerHTML =
    `<option value="" disabled selected>Select image</option>` +
    (pref.length ? `<optgroup label="Recommended">${pref.map(optImage).join("")}</optgroup>` : "") +
    `<optgroup label="All">${rest.map(optImage).join("")}</optgroup>`;
  function optImage(i){
    const label = i.description ? `${i.name} — ${i.description}` : i.name;
    return `<option value="${escapeHtml(i.name)}">${escapeHtml(label)}</option>`;
  }
}

async function loadClients() {
  const r = await fetch("/api/clients");
  const t = await r.json();
  if (!r.ok) return;
  $("#client-list").innerHTML = (t.clients || []).map(c => `<option value="${escapeHtml(c)}"></option>`).join("");
}

/* ---------- drawer logic ---------- */
const drawerEl = $("#drawer");
const drawerCloseBtn = $("#drawer-close");

const D = {
  title: $("#drawer-title"),
  subtitle: $("#drawer-subtitle"),
  id: $("#d-id"),
  status: $("#d-status"),
  client: $("#d-client"),
  location: $("#d-location"),
  type: $("#d-type"),
  ip: $("#d-ip"),
  cores: $("#d-cores"),
  ram: $("#d-ram"),
  disk: $("#d-disk"),
  storage: $("#d-storage"),
  traffic: $("#d-traffic"),
  hourly: $("#d-hourly"),
  monthly: $("#d-monthly"),
  keypath: $("#d-keypath"),
  keybox: $("#d-keybox"),
  keypre: $("#d-keypre"),
  btnDelete: $("#d-delete"),
  btnOpenSite: $("#d-open-site"),
  btnOpenTerm: $("#d-open-term"),
};

function openDrawer(s) {
  CURRENT = s;
  D.title.textContent = s.name || "Server";
  D.subtitle.textContent = s.ip ? `root@${s.ip}` : "no public IP";
  D.id.textContent = s.id;
  D.status.textContent = s.status || "-";
  D.status.dataset.status = (s.status || "").toLowerCase();
  D.client.textContent = s.client || "-";
  D.location.textContent = s.location || "-";
  D.type.textContent = s.typeName || "-";
  D.ip.textContent = s.ip || "-";
  D.cores.textContent = s.cores ?? "—";
  D.ram.textContent = s.memory_gb ?? "—";
  D.disk.textContent = s.disk_gb ?? "—";
  D.storage.textContent = (s.storage_type || "local").toUpperCase();
  D.traffic.textContent = s.included_traffic_tb ?? "—";
  D.hourly.textContent = prettifyPrice(s.price_hourly, s.currency, 4) || "—";
  D.monthly.textContent = prettifyPrice(s.price_monthly, s.currency, 2) || "—";
  D.keypath.textContent = s.keyPath ? basename(s.keyPath) : "-";
  D.keypath.title = s.keyPath || "";

  D.keypre.setAttribute("hidden",""); // прячем прошлый ключ
  D.keypre.textContent = "";

  drawerEl.classList.add("is-open");
  drawerEl.setAttribute("aria-hidden","false");
}

function closeDrawer(){
  drawerEl.classList.remove("is-open");
  drawerEl.setAttribute("aria-hidden","true");
  CURRENT = null;
}

drawerEl.addEventListener("click", (e) => {
  if (e.target.dataset.close === "1" || e.target === drawerCloseBtn) closeDrawer();
});

/* actions in drawer */
D.btnOpenSite.addEventListener("click", () => {
  if (!CURRENT?.ip) return setToast("No public IP yet", true);
  window.open(`http://${CURRENT.ip}`, "_blank", "noopener");
});

D.btnOpenTerm.addEventListener("click", () => {
  if (!CURRENT?.id) return;
  openTerminalModal(String(CURRENT.id), CURRENT.ip || "");
});

D.btnDelete.addEventListener("click", async () => {
  if (!CURRENT?.id) return;
  if (!confirm(`Delete server ${CURRENT.id}?`)) return;
  const r = await fetch("/api/delete", {
    method: "POST",
    headers: {"Content-Type":"application/json"},
    body: JSON.stringify({ serverId: CURRENT.id })
  });
  const t = await r.json();
  if (!r.ok) return setToast(t.error || "Delete failed", true);
  setToast(`Deleted ${CURRENT.id}`);
  closeDrawer();
  await Promise.all([loadList(), loadClients()]);
});

D.keybox.addEventListener("toggle", async () => {
  if (!D.keybox.open || !CURRENT?.id) return;
  const r = await fetch(`/api/key/${CURRENT.id}`);
  if (!r.ok) { setToast("Key not found (maybe created outside dashboard).", true); return; }
  D.keypre.textContent = await r.text();
  D.keypre.removeAttribute("hidden");
});

/* copy handlers */
document.addEventListener("click", async (e) => {
  const el = e.target.closest(".copyable");
  if (!el) return;
  const text = el.textContent.trim();
  if (!text) return;
  try { await navigator.clipboard.writeText(text); setToast(`Copied: ${text}`); }
  catch { setToast("Copy failed", true); }
});

/* ---------- spec helper ---------- */
function updateSpecBox() {
  const typeName = typeSel.value; const locName  = locSel.value;
  const type = (META.types || []).find(t => t.name === typeName);
  if (!type || !locName) { specBox.hidden = true; return; }
  specCores.textContent   = type.cores ?? "—";
  specRam.textContent     = type.memory_gb ?? "—";
  specDisk.textContent    = type.disk_gb ?? "—";
  specStorage.textContent = (type.storage_type || "local").toUpperCase();
  const trafficTB = type.included_traffic_bytes ? (type.included_traffic_bytes / (1024**4)) : 20;
  specTraffic.textContent = (Math.round(trafficTB * 100) / 100).toString();
  const p = (type.prices || []).find(x => x.location === locName) || (type.prices || [])[0] || null;
  specHourly.textContent  = p ? prettifyPrice(p.hourly, p.currency, 4) : "—";
  specMonthly.textContent = p ? prettifyPrice(p.monthly, p.currency, 2) : "—";
  specBox.hidden = false;
}

/* ---------- helpers ---------- */
function prettifyPrice(v, currency = "€", maxFrac = 4) {
  if (!v) return null;
  const num = parseFloat(String(v).replace(/[^\d.]/g, ""));
  if (Number.isNaN(num)) return String(v);
  const fmt = new Intl.NumberFormat(undefined, { style: "currency", currency: currency === "€" ? "EUR" : "EUR", minimumFractionDigits: 0, maximumFractionDigits: maxFrac });
  return fmt.format(num).replace("EUR", "€");
}
function basename(p) { if (!p) return p; return p.split("/").filter(Boolean).pop(); }
function setToast(msg, isErr = false) {
  toastEl.textContent = msg || "";
  toastEl.className = "toast " + (isErr ? "toast--err" : "toast--ok");
  if (!msg) return; clearTimeout(setToast._t);
  setToast._t = setTimeout(() => { toastEl.textContent=""; toastEl.className="toast"; }, 3000);
}

/* ---------- terminal modal + websocket (как было) ---------- */
let term, fitAddon, ws, lastChunk = "";
const modalEl = $("#term-modal");
const termEl  = $("#terminal");
const termCopyBtn  = $("#term-copy");

function openTerminalModal(serverId, ip) {
  if (!serverId) return setToast("Unknown server id", true);
  showModal(true, `Server terminal — ${ip || serverId}`);

  if (!term) {
    term = new window.Terminal({
      cursorBlink: true,
      fontFamily: 'ui-monospace, Menlo, Consolas, monospace',
      theme: { background: '#0b0f19' }
    });
    fitAddon = new window.FitAddon.FitAddon();
    term.loadAddon(fitAddon);
    term.open(termEl);
    observeResize(() => { try { fitAddon.fit(); sendResize(); } catch {} });
    term.onData((data) => sendData(data));
  } else {
    term.clear();
  }

  try { fitAddon.fit(); } catch {}
  connectWs(serverId);
}

function connectWs(serverId) {
  const proto = location.protocol === "https:" ? "wss" : "ws";
  const url = `${proto}://${location.host}/ws/ssh`;
  ws?.close?.();
  ws = new WebSocket(url);

  ws.onopen = () => {
    $("#term-status").textContent = "Connected";
    const { cols, rows } = term ? term : { cols: 120, rows: 30 };
    ws.send(JSON.stringify({ type: "start", serverId, cols, rows }));
  };

  ws.onmessage = (ev) => {
    try {
      const msg = JSON.parse(ev.data);
      if (msg.type === "ready") { term.focus(); return; }
      if (msg.type === "data")  { term.write(msg.data); lastChunk = msg.data; return; }
      if (msg.type === "error") { term.write(`\r\n\x1b[31m${msg.message}\x1b[0m\r\n`); $("#term-status").textContent = "Error"; return; }
      if (msg.type === "exit")  { $("#term-status").textContent = "Session closed"; return; }
    } catch {
      term.write(ev.data);
    }
  };

  ws.onclose = () => { $("#term-status").textContent = "Disconnected"; };
  ws.onerror = () => { $("#term-status").textContent = "WS error"; };
}

function sendData(data) { if (ws?.readyState === 1) ws.send(JSON.stringify({ type: "data", data })); }
function sendResize() {
  if (!term || ws?.readyState !== 1) return;
  const { cols, rows } = term;
  ws.send(JSON.stringify({ type: "resize", cols, rows }));
}
function showModal(show, title = "Terminal") {
  $("#term-title").textContent = title;
  modalEl.setAttribute("aria-hidden", show ? "false" : "true");
  if (show) modalEl.classList.add("is-open"); else modalEl.classList.remove("is-open");
}
function observeResize(cb) {
  if (observeResize._ready) return;
  observeResize._ready = true;
  const ro = new ResizeObserver(() => cb());
  ro.observe(termEl);
  window.addEventListener("resize", cb);
}
document.addEventListener("click", (e) => {
  if (e.target.id === "term-close" || e.target.dataset.close === "1") {
    showModal(false);
    try { ws?.close?.(); } catch {}
  }
});
$("#term-copy").addEventListener("click", async () => {
  const text = lastChunk || "";
  try { await navigator.clipboard.writeText(text); setToast("Copied output"); } catch { setToast("Copy failed", true); }
});
