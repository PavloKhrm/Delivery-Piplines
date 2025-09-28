const $ = (sel, root = document) => root.querySelector(sel);
const escapeHtml = (s) => String(s).replace(/[&<>"']/g, m => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));

const listEl  = $("#list");
const toastEl = $("#toast");
const formEl  = $("#create-form");
const cardTpl = $("#card-tpl");

const clientInput = $("#client");
const clientList  = $("#client-list");
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

Promise.all([loadMeta(), loadClients(), loadList()]).then(() => {
  [typeSel, locSel].forEach(el => el.addEventListener("change", updateSpecBox));
  updateSpecBox();
});

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

listEl.addEventListener("click", async (e) => {
  const btn = e.target.closest("button[data-action]");
  if (!btn) return;
  const card = e.target.closest(".card");
  const id = card?.dataset.id;
  const action = btn.dataset.action;

  if (action === "delete") {
    if (!confirm(`Delete server ${id}?`)) return;
    const r = await fetch("/api/delete", {
      method: "POST",
      headers: {"Content-Type":"application/json"},
      body: JSON.stringify({ serverId: id })
    });
    const t = await r.json();
    if (!r.ok) return setToast(t.error || "Delete failed", true);
    setToast(`Deleted ${id}`);
    await Promise.all([loadList(), loadClients()]);
    return;
  }

  if (action === "show-key") {
    const pre = card.querySelector(".key");
    if (!pre.hasAttribute("hidden")) { pre.setAttribute("hidden",""); return; }
    const r = await fetch(`/api/key/${id}`);
    if (!r.ok) return setToast("Key not found (maybe created outside dashboard).", true);
    pre.textContent = await r.text();
    pre.removeAttribute("hidden");
  }
});

async function loadMeta() {
  const r = await fetch("/api/meta");
  const t = await r.json();
  if (!r.ok) { setToast(t.error || "Failed to load meta", true); return; }
  META = t;

  typeSel.innerHTML = `<option value="" disabled selected>Select type</option>` +
    (t.types || []).map(x =>
      `<option value="${escapeHtml(x.name)}" data-type-id="${x.id}">${escapeHtml(x.name)} (${x.cores} vCPU / ${x.memory_gb} GB)</option>`
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

async function loadList() {
  const r = await fetch("/api/list");
  const t = await r.json();
  if (!r.ok) return setToast(t.error || "Load failed", true);

  listEl.innerHTML = "";
  (t.servers || []).forEach(s => {
    const node = cardTpl.content.firstElementChild.cloneNode(true);
    node.dataset.id = s.id;
    node.querySelector(".card__title").textContent = s.name;
    const badge = node.querySelector(".badge");
    badge.dataset.status = (s.status || "").toLowerCase();
    badge.textContent = s.status || "-";
    fill(node, "id", s.id);
    fill(node, "ip", s.ip || "-");
    fill(node, "client", s.client || "-");
    fill(node, "location", s.location || "-");
    fill(node, "typeName", s.typeName || "-");
    fill(node, "cores", s.cores ?? "-");
    fill(node, "memory_gb", s.memory_gb ?? "-");
    fill(node, "disk_gb", s.disk_gb ?? "-");
    fill(node, "storage_type", s.storage_type ?? "-");
    fill(node, "included_traffic_tb", s.included_traffic_tb ?? "-");

    const pm = prettifyPrice(s.price_monthly, s.currency, 2);
    const ph = prettifyPrice(s.price_hourly, s.currency, 4);
    fill(node, "price_monthly", pm || "—");
    fill(node, "price_hourly", ph || "—");

    const keyEl = node.querySelector('[data-k="keyPath"]');
    keyEl.textContent = s.keyPath ? basename(s.keyPath) : "-";
    keyEl.title = s.keyPath || "";

    listEl.appendChild(node);
  });

  if (!t.servers?.length) {
    listEl.innerHTML = `<p class="muted">No servers yet. Create your first one above.</p>`;
  }
}

function fill(root, key, val) {
  const el = root.querySelector(`[data-k="${key}"]`);
  if (el) el.textContent = val;
}

function prettifyPrice(v, currency = "€", maxFrac = 4) {
  if (!v) return null;
  const num = parseFloat(String(v).replace(/[^\d.]/g, ""));
  if (Number.isNaN(num)) return String(v);
  const fmt = new Intl.NumberFormat(undefined, {
    style: "currency",
    currency: currency === "€" ? "EUR" : "EUR",
    minimumFractionDigits: 0,
    maximumFractionDigits: maxFrac
  });
  return fmt.format(num).replace("EUR", "€");
}

function basename(p) {
  if (!p) return p;
  return p.split("/").filter(Boolean).pop();
}

function setToast(msg, isErr = false) {
  toastEl.textContent = msg || "";
  toastEl.className = "toast " + (isErr ? "toast--err" : "toast--ok");
  if (!msg) return;
  clearTimeout(setToast._t);
  setToast._t = setTimeout(() => { toastEl.textContent=""; toastEl.className="toast"; }, 5000);
}

function updateSpecBox() {
  const typeName = typeSel.value;
  const locName  = locSel.value;
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
