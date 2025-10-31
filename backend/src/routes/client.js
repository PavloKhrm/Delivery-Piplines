// backend/src/routes/client.js
import express from "express";
import fs from "fs";
import { log } from "../../lib/log.js";
import {
  loadClusterMeta,
  getPrivateKeyFileByServerId,
  saveClientMeta,
  buildUserDataK3sAgent,
  createRawServer,
} from "../../lib/hetzner.js";
import { sshExec, waitForSSH } from "../../lib/ssh.js";
import { kubectlApplyRemote, kubectlLabelTaint } from "../../lib/k8s.js";
import { getTags } from "../svc/tags.js";

const { repo, apiTag, webTag } = getTags();
const DEF_API = `index.docker.io/${repo}/client-api:${apiTag || "latest"}`;
const DEF_WEB = `index.docker.io/${repo}/client-web:${webTag || "latest"}`;

const router = express.Router();

async function waitNodeJoin({ host, key, nodeName, maxWait = 600, every = 5 }) {
  const deadline = Date.now() + maxWait * 1000;
  while (Date.now() < deadline) {
    const r = await sshExec({ host, privateKey: key, cmd: "kubectl get nodes --no-headers", timeoutMs: 20000 });
    if ((r.stdout || "").includes(nodeName)) return true;
    await new Promise(rz => setTimeout(rz, every * 1000));
  }
  return false;
}

async function getIngressHttpNodePort(host, key) {
  const r = await sshExec({
    host, privateKey: key, timeoutMs: 15000,
    cmd: "kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}'"
  });
  return (r.stdout || "").trim().replace(/^'/, "").replace(/'$/, "") || "80";
}

router.post("/client/create", async (req, res) => {
  const {
    clusterId,
    clientId,
    serverType = "cx22",
    location = "hel1",
    image = "ubuntu-24.04",
    apiImage = process.env.DEFAULT_API_IMAGE || "docker.io/pavlokhar/client-api:latest",
    webImage = process.env.DEFAULT_WEB_IMAGE || "docker.io/pavlokhar/client-web:latest",
    apiPort = Number(process.env.DEFAULT_API_PORT || 3000),
    webPort = Number(process.env.DEFAULT_WEB_PORT || 80),
  } = req.body || {};

  const cid = String(clientId || "").trim().toLowerCase().replace(/[^a-z0-9-]/g, "-").replace(/^-+|-+$/g, "");
  const step = (s, extra={}) => log("[client] " + s, { cid, clusterId, serverType, location, image, ...extra });

  if (!clusterId || !cid) return res.status(400).json({ ok: false, error: "clusterId, clientId required" });
  if (!apiImage || !webImage) return res.status(400).json({ ok: false, error: "DEFAULT_API_IMAGE/WEB_IMAGE not set" });

  try {
    step("init", { apiImage, webImage });

    const meta = loadClusterMeta(String(clusterId));
    if (!meta) throw new Error("cluster meta not found");
    const cpIp = meta.ip;
    const cpKey = fs.readFileSync(getPrivateKeyFileByServerId(meta.serverId), "utf8");
    const token = (meta.token || "").trim();
    if (!token) throw new Error("cluster token empty");

    const nodeName = `${cid}-node-${Date.now()}`;
    step("hetzner.server.create.start", { nodeName });
    const { serverId, ip, privateKeyFile } = await createRawServer({
      name: nodeName,
      serverType,
      location,
      image,
      labels: { role: "worker", client: cid, clusterId: String(clusterId) },
      user_data: buildUserDataK3sAgent({ masterIp: cpIp, token, nodeName }),
    });
    step("hetzner.server.created", { serverId, ip });

    const key = fs.readFileSync(privateKeyFile, "utf8");
    step("ssh.wait", { ip });
    const ok = await waitForSSH({ host: ip, privateKey: key, attempts: 60, intervalMs: 5000 });
    if (!ok) throw new Error("client ssh not ready");
    step("ssh.ready");

    step("k8s.join.wait", { nodeName });
    const joined = await waitNodeJoin({ host: cpIp, key: cpKey, nodeName, maxWait: 600, every: 5 });
    if (!joined) throw new Error("node not joined");
    step("k8s.joined");

    step("k8s.node.label.taint");
    await kubectlLabelTaint({ host: cpIp, key: cpKey, nodeName, clientId: cid });
    step("k8s.node.labeled");

    const nsMan = `
apiVersion: v1
kind: Namespace
metadata:
  name: "${cid}"
  labels:
    managed-by: dashboard
`;
    step("k8s.ns.apply");
    await kubectlApplyRemote({ host: cpIp, key: cpKey, manifest: nsMan });
    step("k8s.ns.ready", { ns: cid });

    const man = `
apiVersion: apps/v1
kind: Deployment
metadata: { name: api, namespace: "${cid}" }
spec:
  replicas: 1
  selector: { matchLabels: { app: api } }
  template:
    metadata: { labels: { app: api } }
    spec:
      nodeSelector: { client: "${cid}" }
      tolerations:
        - key: client
          operator: Equal
          value: "${cid}"
          effect: NoSchedule
      containers:
        - name: api
          image: ${apiImage}
          imagePullPolicy: Always
          ports: [ { containerPort: ${apiPort} } ]
---
apiVersion: v1
kind: Service
metadata: { name: api, namespace: "${cid}" }
spec:
  selector: { app: api }
  ports: [ { port: 80, targetPort: ${apiPort} } ]
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: web, namespace: "${cid}" }
spec:
  replicas: 1
  selector: { matchLabels: { app: web } }
  template:
    metadata: { labels: { app: web } }
    spec:
      nodeSelector: { client: "${cid}" }
      tolerations:
        - key: client
          operator: Equal
          value: "${cid}"
          effect: NoSchedule
      containers:
        - name: web
          image: ${webImage}
          imagePullPolicy: Always
          ports: [ { containerPort: ${webPort} } ]
---
apiVersion: v1
kind: Service
metadata: { name: web, namespace: "${cid}" }
spec:
  selector: { app: web }
  ports: [ { port: 80, targetPort: ${webPort} } ]
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: "${cid}"
  namespace: "${cid}"
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /${cid}/api/
            pathType: Prefix
            backend:
              service:
                name: api
                port: { number: 80 }
          - path: /${cid}/
            pathType: Prefix
            backend:
              service:
                name: web
                port: { number: 80 }
`;
    step("k8s.app.apply");
    await kubectlApplyRemote({ host: cpIp, key: cpKey, manifest: man });
    step("k8s.app.applied");

    const nodePort = await getIngressHttpNodePort(cpIp, cpKey);
    saveClientMeta({ clientId: cid, serverId, ip: cpIp, clusterId, nodeName });
    const url = `http://${cpIp}:${nodePort}/${cid}/`;

    step("ready", { url });
    return res.json({ ok: true, clientId: cid, clusterId, nodeName, ip: cpIp, url });
  } catch (e) {
    step("error", { error: String(e?.message || e) });
    return res.status(500).json({ ok: false, error: String(e?.message || e) });
  }
});

export default router;
