// backend/src/svc/rollout.js
import fs from "fs";
import { loadClusterMeta, listClusters, getPrivateKeyFileByServerId } from "../../lib/hetzner.js";
import { sshExec } from "../../lib/ssh.js";

const log = (evt, obj = {}) => console.log(new Date().toISOString(), "[rollout]", evt, obj);

export async function rolloutAllNamespaces({ cpIp, repo, apiTag, webTag }) {
  const apiImage = `docker.io/${repo}/client-api:${apiTag}`;
  const webImage = `docker.io/${repo}/client-web:${webTag}`;

  const script = `
set -e
ns_list=$(kubectl get ns -l managed-by=dashboard -o jsonpath='{.items[*].metadata.name}')
for n in $ns_list; do
  kubectl -n "$n" set image deploy/api api=${apiImage} || true
  kubectl -n "$n" set image deploy/web web=${webImage} || true
  kubectl -n "$n" rollout status deploy/api --timeout=180s || true
  kubectl -n "$n" rollout status deploy/web --timeout=180s || true
done
echo "OK"
`.trim();

  log("exec", { cpIp, repo, apiTag, webTag });
  const r = await sshExec({ host: cpIp, privateKey: await getCpKey(cpIp), cmd: script, timeoutMs: 240000 });
  if (r.code !== 0) throw new Error(r.stderr || r.stdout || "rollout failed");
  log("ok", { cpIp, out: (r.stdout || "").slice(0, 5000) });
  return r.stdout || "OK";
}

async function getCpKey(cpIp) {
  // ищем кластер по IP и достаём его приватный ключ
  const clusters = listClusters();
  const found = clusters.find(c => {
    const meta = loadClusterMeta(String(c.clusterId));
    return meta?.ip === cpIp;
  });
  if (!found) throw new Error("control-plane cluster not found by ip");
  const meta = loadClusterMeta(String(found.clusterId));
  const keyFile = getPrivateKeyFileByServerId(meta.serverId);
  return fs.readFileSync(keyFile, "utf8");
}

// совместимость со старым именем
export async function patchAllClientDeployments({ namespace, apiTag, webTag }) {
  const repo = namespace;
  const clusters = listClusters();
  for (const c of clusters) {
    const meta = loadClusterMeta(String(c.clusterId));
    if (!meta?.ip) continue;
    await rolloutAllNamespaces({ cpIp: meta.ip, repo, apiTag, webTag });
  }
}
