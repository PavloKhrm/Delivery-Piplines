import dotenv from "dotenv";
dotenv.config();
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { genOpenSSHKeyPair } from "./ssh.js";
import { buildUserDataDocker, buildUserDataK3sServer, buildUserDataK3sAgent } from "./provision.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const API = "https://api.hetzner.cloud/v1";

function getToken() {
  const t = process.env.HCLOUD_TOKEN;
  if (!t) throw new Error("HCLOUD_TOKEN missing");
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
const DB_SERVERS = path.join(DATA_DIR, "servers.json");
const DB_CLUSTERS = path.join(DATA_DIR, "clusters.json");
const DB_CLIENTS = path.join(DATA_DIR, "clients.json");
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
for (const f of [DB_SERVERS, DB_CLUSTERS, DB_CLIENTS]) if (!fs.existsSync(f)) fs.writeFileSync(f, JSON.stringify({}), "utf8");

function readJSON(f) { try { return JSON.parse(fs.readFileSync(f, "utf8")); } catch { return {}; } }
function writeJSON(f, obj) { fs.writeFileSync(f, JSON.stringify(obj, null, 2)); }

export async function listServerTypes() {
  const r = await hcloud("/server_types?per_page=200");
  return (r.server_types || []).map(t => ({ id: t.id, name: t.name, cores: t.cores, memory_gb: t.memory, disk_gb: t.disk }));
}

export async function listLocations() {
  const r = await hcloud("/locations");
  return (r.locations || []).map(l => ({ name: l.name, city: l.city, country: l.country }));
}

export async function listSystemImages() {
  const r = await hcloud("/images?type=system&per_page=200");
  return (r.images || []).map(i => ({ id: i.id, name: i.name, description: i.description || "" }));
}

export async function listServers() {
  const list = await hcloud("/servers?per_page=200");
  return (list.servers || []).map(s => ({
    id: s.id,
    name: s.name,
    ip: s.public_net?.ipv4?.ip || null,
    status: s.status,
    created: s.created,
    labels: s.labels || {},
    client: s.labels?.client || null
  }));
}

export async function createRawServer({ name, serverType = "cx22", location = "hel1", image = "ubuntu-24.04", labels = {}, user_data }) {
  const { publicKey, privateKey, privateKeyFile } = genOpenSSHKeyPair(name);
  const ssh = await hcloud("/ssh_keys", { method: "POST", body: JSON.stringify({ name: `${name}-${Date.now()}`, public_key: publicKey, labels: { managed: "true" } }) });
  const resp = await hcloud("/servers", { method: "POST", body: JSON.stringify({ name, server_type: serverType, image, location, ssh_keys: [ssh.ssh_key.id], labels, user_data }) });
  const ip = resp.server?.public_net?.ipv4?.ip || null;
  const db = readJSON(DB_SERVERS);
  db[resp.server.id] = { privateKeyFile, created: Date.now(), name, labels, ip };
  writeJSON(DB_SERVERS, db);
  return { serverId: resp.server.id, ip, privateKeyFile };
}

export function getPrivateKeyFileByServerId(serverId) {
  const db = readJSON(DB_SERVERS);
  return db[serverId]?.privateKeyFile || null;
}

export function saveClusterMeta({ clusterId, serverId, ip, kubeconfig, token }) {
  const dir = path.join(DATA_DIR, "clusters");
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  const clusterDir = path.join(dir, String(clusterId));
  if (!fs.existsSync(clusterDir)) fs.mkdirSync(clusterDir, { recursive: true });
  const kubeFile = path.join(clusterDir, "kubeconfig.yaml");
  const tokenFile = path.join(clusterDir, "node-token.txt");
  fs.writeFileSync(kubeFile, kubeconfig, "utf8");
  fs.writeFileSync(tokenFile, token, "utf8");
  const db = readJSON(DB_CLUSTERS);
  db[clusterId] = { serverId, ip, kubeconfigFile: kubeFile, tokenFile, created: Date.now() };
  writeJSON(DB_CLUSTERS, db);
  return { kubeconfigFile: kubeFile, tokenFile };
}

export function loadClusterMeta(clusterId) {
  const db = readJSON(DB_CLUSTERS);
  const row = db[clusterId];
  if (!row) return null;
  const kubeconfig = fs.readFileSync(row.kubeconfigFile, "utf8");
  const token = fs.readFileSync(row.tokenFile, "utf8");
  return { ...row, kubeconfig, token };
}

export function listClusters() {
  const db = readJSON(DB_CLUSTERS);
  return Object.entries(db).map(([id, v]) => ({ clusterId: id, serverId: v.serverId, ip: v.ip, created: v.created }));
}

export function saveClientMeta({ clientId, serverId, ip, clusterId, nodeName }) {
  const db = readJSON(DB_CLIENTS);
  db[clientId] = { serverId, ip, clusterId, nodeName, created: Date.now() };
  writeJSON(DB_CLIENTS, db);
  return db[clientId];
}

export function listClients() {
  const db = readJSON(DB_CLIENTS);
  return Object.entries(db).map(([id, v]) => ({ clientId: id, ...v }));
}

export async function deleteServer(serverId) {
  await hcloud(`/servers/${serverId}`, { method: "DELETE" });
  const db = readJSON(DB_SERVERS);
  delete db[serverId];
  writeJSON(DB_SERVERS, db);
}

export function setKubeconfigServerIP(kubeconfig, publicIp) {
  try {
    const obj = JSON.parse(JSON.stringify(kubeconfig));
  } catch {}
  const replaced = kubeconfig.replace(/server:\s*https?:\/\/[0-9.:a-zA-Z-]+:6443/g, `server: https://${publicIp}:6443`);
  return replaced;
}

export function getServerIPById(serverId) {
  const db = readJSON(DB_SERVERS);
  return db[serverId]?.ip || null;
}

export { buildUserDataDocker, buildUserDataK3sServer, buildUserDataK3sAgent };
