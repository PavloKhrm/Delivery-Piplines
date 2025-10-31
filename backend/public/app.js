const $ = (sel, root = document) => root.querySelector(sel);
const escapeHtml = (s) => String(s).replace(/[&<>"']/g, m => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));

const toastEl = $("#toast");

const clForm = $("#create-cluster-form");
const clName = $("#cl-name");
const clType = $("#cl-type");
const clLoc  = $("#cl-loc");
const clImg  = $("#cl-image");

const cForm = $("#create-client-form");
const cId   = $("#client-id");
const cClus = $("#client-cluster");
const cType = $("#cln-type");
const cLoc  = $("#cln-loc");
const cImg  = $("#cln-image");
const apiImg= $("#api-image");
const webImg= $("#web-image");
const apiPrt= $("#api-port");
const webPrt= $("#web-port");

const tabs = [...document.querySelectorAll(".tab")];
const panes = [...document.querySelectorAll(".tab-pane")];

const clustersEl = $("#clusters");
const clientsEl  = $("#clients");
const serversEl  = $("#servers");

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
  keypath: $("#d-keypath"),
  keybox: $("#d-keybox"),
  keypre: $("#d-keypre"),
  btnDelete: $("#d-delete"),
  btnOpenSite: $("#d-open-site"),
  btnOpenTerm: $("#d-open-term"),
};

let META = { types: [], locations: [], images: [] };
let CURRENT = null;

init();

function init(){
  bindTabs();
  loadMeta();
  refreshAll();
  clForm.addEventListener("submit", onCreateCluster);
  cForm.addEventListener("submit", onCreateClient);
  drawerEl.addEventListener("click", (e) => {
    if (e.target.dataset.close === "1" || e.target === drawerCloseBtn) closeDrawer();
  });
  D.btnOpenSite.addEventListener("click", () => {
    const ip = CURRENT?.ip;
    const cid = CURRENT?.client || "client";
    if (!ip) return setToast("No ingress IP", true);
    window.open(`http://${ip}/${cid}/`, "_blank", "noopener");
  });
  D.btnOpenTerm.addEventListener("click", () => {
    if (!CURRENT?.id) return;
    openTerminalModal(String(CURRENT.id), CURRENT.ip || "");
  });
  D.btnDelete.addEventListener("click", async () => {
    if (!CURRENT?.id) return;
    if (!confirm(`Delete server ${CURRENT.id}?`)) return;
    const r = await fetch("/api/server/delete", { method: "POST", headers: {"Content-Type":"application/json"}, body: JSON.stringify({ serverId: CURRENT.id }) });
    const t = await r.json();
    if (!r.ok) return setToast(t.error || "Delete failed", true);
    setToast(`Deleted ${CURRENT.id}`);
    closeDrawer();
    refreshAll();
  });
  D.keybox.addEventListener("toggle", async () => {
    if (!D.keybox.open || !CURRENT?.id) return;
    const r = await fetch(`/api/key/${CURRENT.id}`);
    if (!r.ok) return setToast("Key not found", true);
    D.keypre.textContent = await r.text();
    D.keypre.removeAttribute("hidden");
  });
  document.addEventListener("click", async (e) => {
    const el = e.target.closest(".copyable");
    if (!el) return;
    const text = el.textContent.trim();
    if (!text) return;
    try { await navigator.clipboard.writeText(text); setToast(`Copied: ${text}`); }
    catch { setToast("Copy failed", true); }
  });
}

function bindTabs(){
  tabs.forEach(btn => btn.addEventListener("click", () => {
    tabs.forEach(b => b.classList.remove("active"));
    panes.forEach(p => p.classList.remove("is-active"));
    btn.classList.add("active");
    const pane = document.querySelector(`.tab-pane#${btn.dataset.tab}-form`) || document.querySelector(`.${btn.dataset.tab}`) || document.getElementById(btn.dataset.tab+"-form");
    const target = document.getElementById(btn.dataset.tab+"-form");
    if (target) target.classList.add("is-active");
  }));
}

async function loadMeta(){
  try{
    const r = await fetch("/api/meta");
    const t = await r.json();
    if (!r.ok) throw new Error(t.error || "meta failed");
    META = t;
    fillOpts(clType, t.types, (x) => ({v:x.name, l:`${x.name} (${x.cores} vCPU / ${x.memory_gb} GB)`}));
    fillOpts(cType, t.types, (x) => ({v:x.name, l:`${x.name} (${x.cores} vCPU / ${x.memory_gb} GB)`}));
    fillOpts(clLoc, t.locations, (l) => ({v:l.name, l:`${l.name} — ${l.city}, ${l.country}`}));
    fillOpts(cLoc, t.locations, (l) => ({v:l.name, l:`${l.name} — ${l.city}, ${l.country}`}));
    const imgs = (t.images || []).sort((a,b) => (a.name||"").localeCompare(b.name||""));
    const preferred = ["ubuntu-24.04","debian-12","ubuntu-22.04"];
    const pref = imgs.filter(i => preferred.includes(i.name));
    const rest = imgs.filter(i => !preferred.includes(i.name));
    fillImageSelect(clImg, pref, rest);
    fillImageSelect(cImg, pref, rest);
  } catch(e){
    setToast(String(e.message||e), true);
  }
}

function fillOpts(sel, arr, map){
  sel.innerHTML = `<option value="" disabled selected>Select…</option>` + (arr||[]).map(x => {
    const m = map(x); return `<option value="${escapeHtml(m.v)}">${escapeHtml(m.l)}</option>`;
  }).join("");
}

function fillImageSelect(sel, pref, rest){
  sel.innerHTML = `<option value="" disabled selected>Select image</option>` +
    (pref.length ? `<optgroup label="Recommended">${pref.map(i => optImage(i)).join("")}</optgroup>` : "") +
    `<optgroup label="All">${rest.map(i => optImage(i)).join("")}</optgroup>`;
  function optImage(i){
    const label = i.description ? `${i.name} — ${i.description}` : i.name;
    return `<option value="${escapeHtml(i.name)}">${escapeHtml(label)}</option>`;
  }
}

async function refreshAll(){
  await Promise.all([loadClusters(), loadClients(), loadServers()]);
}

async function loadClusters(){
  try{
    const r = await fetch("/api/clusters");
    const t = await r.json();
    if (!r.ok) throw new Error(t.error || "clusters failed");
    const list = t.clusters || [];
    clustersEl.innerHTML = "";
    const tpl = $("#card-cluster");
    list.forEach(c => {
      const n = tpl.content.firstElementChild.cloneNode(true);
      n.querySelector(".cluster-name").textContent = `Cluster ${c.clusterId}`;
      n.querySelector(".ip").textContent = c.ip || "-";
      n.querySelector(".id").textContent = c.clusterId;
      clustersEl.appendChild(n);
    });
    cClus.innerHTML = `<option value="" disabled selected>Pick cluster…</option>` + list.map(c => `<option value="${escapeHtml(c.clusterId)}">${escapeHtml(c.clusterId)} — ${escapeHtml(c.ip||"-")}</option>`).join("");
    if (!list.length) clustersEl.innerHTML = `<p class="muted">No clusters yet. Create one above.</p>`;
  }catch(e){ setToast(String(e.message||e), true); }
}

async function loadClients(){
  try{
    const r = await fetch("/api/clients");
    const t = await r.json();
    if (!r.ok) throw new Error(t.error || "clients failed");
    const list = t.clients || [];
    clientsEl.innerHTML = "";
    const tpl = $("#card-client");
    list.forEach(c => {
      const n = tpl.content.firstElementChild.cloneNode(true);
      n.querySelector(".client-id").textContent = c.clientId;
      n.querySelector(".ip").textContent = c.ip || "-";
      n.querySelector(".cluster-id").textContent = c.clusterId || "-";
      n.querySelector(".node-name").textContent = c.nodeName || "-";
      clientsEl.appendChild(n);
    });
    if (!list.length) clientsEl.innerHTML = `<p class="muted">No clients yet. Create one above.</p>`;
  }catch(e){ setToast(String(e.message||e), true); }
}

async function loadServers(){
  try{
    const r = await fetch("/api/servers");
    const t = await r.json();
    if (!r.ok) throw new Error(t.error || "servers failed");
    const list = t.servers || [];
    serversEl.innerHTML = "";
    const tpl = $("#card-server");
    list.forEach(s => {
      const n = tpl.content.firstElementChild.cloneNode(true);
      n.dataset.id = s.id;
      n.querySelector(".name").textContent = s.name || "server";
      n.querySelector(".status").textContent = s.status || "-";
      n.querySelector(".status").dataset.status = (s.status||"").toLowerCase();
      n.querySelector(".ip").textContent = s.ip || "-";
      n.querySelector(".type").textContent = s.typeName || "-";
      n.querySelector(".location").textContent = s.location || "-";
      n.querySelector(".cores").textContent = s.cores ?? "—";
      n.querySelector(".ram").textContent = s.memory_gb ?? "—";
      n.querySelector(".disk").textContent = s.disk_gb ?? "—";
      n.addEventListener("click", () => openDrawer(s));
      serversEl.appendChild(n);
    });
    if (!list.length) serversEl.innerHTML = `<p class="muted">No servers yet.</p>`;
  }catch(e){ setToast(String(e.message||e), true); }
}

async function onCreateCluster(e){
  e.preventDefault();
  const body = {
    name: clName.value.trim() || `cp-${Date.now()}`,
    serverType: clType.value,
    location: clLoc.value,
    image: clImg.value
  };
  setToast("Creating cluster…");
  console.log("[ui] create cluster", body);
  const r = await fetch("/api/cluster/create", { method: "POST", headers: {"Content-Type":"application/json"}, body: JSON.stringify(body) });
  const t = await r.json();
  if (!r.ok) { setToast(t.error || "Create cluster failed", true); return; }
  setToast(`Cluster ${t.clusterId} at ${t.ip}`);
  await refreshAll();
}

async function onCreateClient(e){
  e.preventDefault();
  const body = {
    clusterId: $("#client-cluster").value,
    clientId:  $("#client-id").value.trim(),
    serverType: $("#cln-type").value,
    location:   $("#cln-loc").value,
    image:      $("#cln-image").value
  };
  const apiVal = $("#api-image").value.trim();
  const webVal = $("#web-image").value.trim();
  const apiPortVal = $("#api-port").value.trim();
  const webPortVal = $("#web-port").value.trim();
  if (apiVal) body.apiImage = apiVal;
  if (webVal) body.webImage = webVal;
  if (apiPortVal) body.apiPort = Number(apiPortVal);
  if (webPortVal) body.webPort = Number(webPortVal);

  if (!body.clusterId || !body.clientId) { setToast("Fill cluster and client id", true); return; }

  setToast(`Creating client ${body.clientId}…`);
  const r = await fetch("/api/client/create", {
    method: "POST",
    headers: {"Content-Type":"application/json"},
    body: JSON.stringify(body)
  });
  const t = await r.json();
  if (!r.ok) { setToast(t.error || "Create client failed", true); return; }
  setToast(`Client ${t.clientId} → ${t.url}`);
  await refreshAll();
}


function openDrawer(s){
  CURRENT = s;
  D.title.textContent = s.name || "Server";
  D.subtitle.textContent = s.ip ? `root@${s.ip}` : "no public IP";
  D.id.textContent = s.id || "-";
  D.status.textContent = s.status || "-";
  D.status.dataset.status = (s.status || "").toLowerCase();
  D.client.textContent = s.client || "-";
  D.location.textContent = s.location || "-";
  D.type.textContent = s.typeName || "-";
  D.ip.textContent = s.ip || "-";
  D.cores.textContent = s.cores ?? "—";
  D.ram.textContent = s.memory_gb ?? "—";
  D.disk.textContent = s.disk_gb ?? "—";
  D.keypath.textContent = s.keyPath ? basename(s.keyPath) : "-";
  D.keypath.title = s.keyPath || "";
  D.keypre.setAttribute("hidden","");
  D.keypre.textContent = "";
  drawerEl.classList.add("is-open");
  drawerEl.setAttribute("aria-hidden","false");
}

function closeDrawer(){
  drawerEl.classList.remove("is-open");
  drawerEl.setAttribute("aria-hidden","true");
  CURRENT = null;
}

function basename(p){ if (!p) return p; return p.split("/").filter(Boolean).pop(); }
function setToast(msg, isErr = false){
  toastEl.textContent = msg || "";
  toastEl.className = "toast " + (isErr ? "toast--err" : "toast--ok");
  if (!msg) return; clearTimeout(setToast._t);
  setToast._t = setTimeout(() => { toastEl.textContent=""; toastEl.className="toast"; }, 4000);
}

let term, fitAddon, ws, lastChunk = "";
const modalEl = $("#term-modal");
const termEl  = $("#terminal");
const termCopyBtn  = $("#term-copy");

function openTerminalModal(serverId, ip){
  showModal(true, `Server terminal — ${ip || serverId}`);
  if (!term) {
    term = new window.Terminal({ cursorBlink: true, fontFamily: 'ui-monospace, Menlo, Consolas, monospace', theme: { background: '#0b0f19' } });
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

function connectWs(serverId){
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
    try{
      const msg = JSON.parse(ev.data);
      if (msg.type === "ready") { term.focus(); return; }
      if (msg.type === "data")  { term.write(msg.data); lastChunk = msg.data; return; }
      if (msg.type === "error") { term.write(`\r\n\x1b[31m${msg.message}\x1b[0m\r\n`); $("#term-status").textContent = "Error"; return; }
      if (msg.type === "exit")  { $("#term-status").textContent = "Session closed"; return; }
    }catch{ term.write(ev.data); }
  };
  ws.onclose = () => { $("#term-status").textContent = "Disconnected"; };
  ws.onerror = () => { $("#term-status").textContent = "WS error"; };
}

function sendData(data){ if (ws?.readyState === 1) ws.send(JSON.stringify({ type: "data", data })); }
function sendResize(){
  if (!term || ws?.readyState !== 1) return;
  const { cols, rows } = term; ws.send(JSON.stringify({ type: "resize", cols, rows }));
}
function showModal(show, title = "Terminal"){
  $("#term-title").textContent = title;
  modalEl.setAttribute("aria-hidden", show ? "false" : "true");
  if (show) modalEl.classList.add("is-open"); else modalEl.classList.remove("is-open");
}
function observeResize(cb){
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
