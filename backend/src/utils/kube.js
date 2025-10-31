import { sshExec } from "../../lib/ssh.js";
export async function waitForK3s({ host, key, maxWaitSec = 600, intervalMs = 5000 }) {
  const deadline = Date.now() + maxWaitSec * 1000;
  while (Date.now() < deadline) {
    try {
      const st = await sshExec({ host, privateKey: key, cmd: "systemctl is-active k3s || true", timeoutMs: 15000 });
      const t = await sshExec({ host, privateKey: key, cmd: "cat /var/lib/rancher/k3s/server/node-token 2>/dev/null || true", timeoutMs: 15000 });
      const k = await sshExec({ host, privateKey: key, cmd: "cat /etc/rancher/k3s/k3s.yaml 2>/dev/null || true", timeoutMs: 15000 });
      const active = (st.stdout || "").trim() === "active";
      const token = (t.stdout || "").trim();
      const kubeconfig = k.stdout || "";
      if (active && token && kubeconfig) return { token, kubeconfig };
    } catch {}
    await new Promise(r => setTimeout(r, intervalMs));
  }
  throw new Error("k3s not ready in time");
}
export async function kubectlApply({ host, key, manifest }) {
  const tmp = Buffer.from(manifest, "utf8").toString("base64");
  const cmd = `echo ${tmp} | base64 -d | kubectl apply -f -`;
  const r = await sshExec({ host, privateKey: key, cmd, timeoutMs: 240000 });
  if (r.code !== 0) throw new Error(r.stderr || "kubectl apply failed");
  return r.stdout || "";
}
export async function kubectlLabelTaint({ host, key, nodeName, clientId }) {
  const cmd = `kubectl label node ${nodeName} client=${clientId} --overwrite && kubectl taint node ${nodeName} client=${clientId}:NoSchedule --overwrite`;
  const r = await sshExec({ host, privateKey: key, cmd, timeoutMs: 30000 });
  if (r.code !== 0) throw new Error(r.stderr || "label/taint failed");
  return r.stdout || "";
}
export async function getIngressHttpNodePort(host, key) {
  const r = await sshExec({
    host,
    privateKey: key,
    cmd: "kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}'",
    timeoutMs: 15000
  });
  return (r.stdout || "").trim() || "80";
}
