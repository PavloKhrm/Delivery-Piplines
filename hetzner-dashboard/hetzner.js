// hetzner.js
import dotenv from "dotenv";
dotenv.config(); 

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { genOpenSSHKeyPair } from "./ssh.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const API = "https://api.hetzner.cloud/v1";

function getToken() {
  const t = process.env.HCLOUD_TOKEN;
  if (!t) throw new Error("HCLOUD_TOKEN missing in .env");
  return t;
}
function headers() {
  return { Authorization: `Bearer ${getToken()}`, "Content-Type": "application/json" };
}
async function hcloud(pathname, opts = {}) {
  const r = await fetch(`${API}${pathname}`, { ...opts, headers: headers() });
  if (!r.ok) {
    const text = await r.text().catch(() => "");
    throw new Error(`API ${pathname} failed: ${r.status}${text ? ` | ${text}` : ""}`);
  }
  return r.json();
}

const DATA_DIR = path.join(__dirname, "data");
const DB_FILE = path.join(DATA_DIR, "servers.json");
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
if (!fs.existsSync(DB_FILE)) fs.writeFileSync(DB_FILE, JSON.stringify({}), "utf8");

function readDB() {
  try { return JSON.parse(fs.readFileSync(DB_FILE, "utf8")); }
  catch { return {}; }
}
function writeDB(obj) {
  fs.writeFileSync(DB_FILE, JSON.stringify(obj, null, 2));
}

// ЗАМЕНИ listServers на версию ниже
export async function listServers() {
    const [list, types, locs] = await Promise.all([
      hcloud("/servers?per_page=200"),
      listServerTypes(),
      listLocations()
    ]);
    const typeById = new Map(types.map(t => [t.id, t]));
    const locSet = new Set(locs.map(l => l.name));
  
    return (list.servers || []).map(s => {
      const typeId = s.server_type?.id ?? s.server_type_id ?? null;
      const t = typeId ? typeById.get(typeId) : null;
  
      const location = s.datacenter?.location?.name || s.public_net?.ipv4?.dns_ptr?.split(".").pop() || null;
  
      let priceMonthly = null, priceHourly = null, currency = "€";
      if (t && location) {
        const p = (t.prices || []).find(x => x.location === location) || (t.prices || [])[0];
        if (p) { priceMonthly = p.monthly; priceHourly = p.hourly; currency = p.currency || currency; }
      }
  
      return {
        id: s.id,
        name: s.name,
        ip: s.public_net?.ipv4?.ip || null,
        status: s.status,
        created: s.created,
        labels: s.labels || {},
        client: s.labels?.client || null,
        location: location && locSet.has(location) ? location : (location || "-"),
        keyPath: readDB()[s.id]?.privateKeyFile || null,
  
        typeName: t?.name || null,
        cores: t?.cores ?? null,
        memory_gb: t?.memory_gb ?? null,
        disk_gb: t?.disk_gb ?? null,
        storage_type: t?.storage_type ?? null,
        included_traffic_tb: t?.included_traffic_bytes ? +(t.included_traffic_bytes / (1024**4)).toFixed(2) : 20, // дефолт 20 TB
        price_monthly: priceMonthly,
        price_hourly: priceHourly,
        currency
      };
    });
  }
  

export async function createServer({
  client = "client-a",
  serverType = "cx22",
  location = "hel1",
  image = "ubuntu-24.04",
  namePrefix = "srv",
} = {}) {
  const { publicKey, privateKey, privateKeyFile } = genOpenSSHKeyPair(client);

  const ssh = await hcloud("/ssh_keys", {
    method: "POST",
    body: JSON.stringify({
      name: `${client}-${Date.now()}`,
      public_key: publicKey,
      labels: { client, managed: "true" },
    }),
  });

  const serverName = `${client}-${namePrefix}-${Date.now()}`;
  const createResp = await hcloud("/servers", {
    method: "POST",
    body: JSON.stringify({
      name: serverName,
      server_type: serverType,
      image,
      location,
      ssh_keys: [ssh.ssh_key.id],
      labels: { client },
    }),
  });

  const server = createResp.server;
  const ip = server?.public_net?.ipv4?.ip || null;

  const db = readDB();
  db[server.id] = { client, privateKeyFile, serverName, created: Date.now() };
  writeDB(db);

  return {
    client,
    serverId: server.id,
    serverName,
    ip,
    privateKeyFile,
    privateKey,
    hint: ip ? `ssh -i "${privateKeyFile}" root@${ip}` : null,
  };
}

export async function deleteServer(serverId) {
  await hcloud(`/servers/${serverId}`, { method: "DELETE" });
  const db = readDB();
  delete db[serverId];
  writeDB(db);
}

export async function getPrivateKey(serverId) {
  const row = readDB()[serverId];
  if (!row?.privateKeyFile) return null;
  if (!fs.existsSync(row.privateKeyFile)) return null;
  return fs.readFileSync(row.privateKeyFile, "utf8");
}


export async function listServerTypes() {
  const r = await hcloud("/server_types?per_page=200");
  const types = (r.server_types || []).map(t => ({
    id: t.id,
    name: t.name,           
    cores: t.cores,         
    memory_gb: t.memory,     
    disk_gb: t.disk,         
    storage_type: t.storage_type || "local",
    cpu_type: t.cpu_type || "shared",
    included_traffic_bytes: t.included_traffic ?? null,
    prices: (t.prices || []).map(p => ({
      location: p.location,
      hourly: pickPrice(p.price_hourly),   
      monthly: pickPrice(p.price_monthly),
      currency: guessCurrency(p.price_monthly) || guessCurrency(p.price_hourly) || "€"
    }))
  }));
  return types;
}

function pickPrice(obj) {
  if (!obj) return null;
  return obj.gross ?? obj.net ?? obj.value ?? null;
}
function guessCurrency(obj) {
  if (!obj) return null;
  if (typeof obj.gross === "string" && obj.gross.trim().startsWith("€")) return "€";
  if (typeof obj.net === "string" && obj.net.trim().startsWith("€")) return "€";
  if (obj.currency === "EUR") return "€";
  return null;
}

  
  export async function listLocations() {
    const r = await hcloud("/locations");
    return (r.locations || []).map(l => ({
      name: l.name,             
      city: l.city,             
      country: l.country
    }));
  }
  
  export async function listSystemImages() {

    const r = await hcloud("/images?type=system&per_page=200");
    return (r.images || []).map(i => ({
      id: i.id,
      name: i.name,            
      description: i.description || "",
      os_flavor: i.os_flavor || "",
      architecture: i.architecture || ""
    }));
  }
  
  export async function listClientsFromLabels() {
    const r = await hcloud("/servers?per_page=200");
    const set = new Set();
    (r.servers || []).forEach(s => {
      const c = s.labels?.client;
      if (c) set.add(c);
    });
    return Array.from(set).sort();
  }
  