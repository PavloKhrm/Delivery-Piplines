// backend/src/routes/cluster.js
import express from "express";
import fs from "fs";
import { log } from "../../lib/log.js";
import {
  createRawServer,
  saveClusterMeta,
  setKubeconfigServerIP,
  buildUserDataK3sServer,
} from "../../lib/hetzner.js";
import { sshExec, waitForSSH } from "../../lib/ssh.js";

const router = express.Router();

async function waitForK3s({ host, key, maxWaitSec = 600, intervalMs = 5000 }) {
  const deadline = Date.now() + maxWaitSec * 1000;
  while (Date.now() < deadline) {
    try {
      const st = await sshExec({ host, privateKey: key, cmd: "systemctl is-active k3s || true", timeoutMs: 15000 });
      const active = (st.stdout || "").trim() === "active";
      const t = await sshExec({ host, privateKey: key, cmd: "cat /var/lib/rancher/k3s/server/node-token 2>/dev/null || true", timeoutMs: 15000 });
      const k = await sshExec({ host, privateKey: key, cmd: "cat /etc/rancher/k3s/k3s.yaml 2>/dev/null || true", timeoutMs: 15000 });
      const token = (t.stdout || "").trim();
      const kubeconfig = k.stdout || "";
      if (active && token && /server:\s*https?:\/\//.test(kubeconfig)) return { token, kubeconfig };
    } catch {}
    await new Promise(r => setTimeout(r, intervalMs));
  }
  throw new Error("k3s not ready in time");
}

router.post("/cluster/create", async (req, res) => {
  const { name = `cp-${Date.now()}`, serverType = "cx32", location = "hel1", image = "ubuntu-24.04" } = req.body || {};
  const step = (s, extra={}) => log("[cluster] " + s, { name, serverType, location, image, ...extra });
  try {
    step("init");
    const { serverId, ip, privateKeyFile } = await createRawServer({
      name,
      serverType,
      location,
      image,
      labels: { role: "control-plane" },
      user_data: buildUserDataK3sServer(),
    });
    step("hetzner.server.created", { serverId, ip });

    const key = fs.readFileSync(privateKeyFile, "utf8");
    step("ssh.wait");
    const sshOk = await waitForSSH({ host: ip, privateKey: key, attempts: 60, intervalMs: 5000 });
    if (!sshOk) throw new Error("SSH not ready");
    step("ssh.ready", { ip });

    step("k3s.wait");
    const { token, kubeconfig } = await waitForK3s({ host: ip, key, maxWaitSec: 600, intervalMs: 5000 });
    step("k3s.ready", { tokenBytes: token.length });

    const kubeFixed = setKubeconfigServerIP(kubeconfig, ip);
    const { kubeconfigFile, tokenFile } = saveClusterMeta({
      clusterId: serverId,
      serverId,
      ip,
      kubeconfig: kubeFixed,
      token,
    });
    step("meta.saved", { kubeconfigFile, tokenFile });

    step("ingress.install");
    const rIn = await sshExec({
      host: ip,
      privateKey: key,
      timeoutMs: 300000,
      cmd: "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml && kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=240s",
    });
    if (rIn.code !== 0) throw new Error(rIn.stderr || "ingress install failed");
    step("ingress.ready");

    const rNodes = await sshExec({ host: ip, privateKey: key, cmd: "kubectl get nodes -o wide", timeoutMs: 20000 });
    step("k8s.nodes", { out: rNodes.stdout?.slice(0, 500) || "" });

    step("done", { clusterId: String(serverId), ip });
    return res.json({ ok: true, clusterId: String(serverId), ip, serverId });
  } catch (e) {
    step("error", { error: String(e?.message || e) });
    return res.status(500).json({ ok: false, error: String(e?.message || e) });
  }
});

export default router;
