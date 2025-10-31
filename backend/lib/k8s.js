import { sshExec } from "./ssh.js";

export async function kubectlApplyRemote({ host, key, manifest }) {
  const b64 = Buffer.from(manifest, "utf8").toString("base64");
  const cmd = `echo '${b64}' | base64 -d | kubectl apply -f -`;
  const r = await sshExec({ host, privateKey: key, cmd, timeoutMs: 120000 });
  return r;
}

export async function kubectlGetNodeNameByInternal({ host, key, internalNameHint }) {
  const cmd = `kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{\"|\"}{.status.addresses[*].address}{\"\\n\"}{end}'`;
  const r = await sshExec({ host, privateKey: key, cmd, timeoutMs: 20000 });
  const lines = (r.stdout || "").trim().split("\n").filter(Boolean);
  for (const ln of lines) {
    const [name, addrs] = ln.split("|");
    if (name.includes(internalNameHint) || (addrs || "").includes(internalNameHint)) return name;
  }
  return null;
}

export async function kubectlLabelTaint({ host, key, nodeName, clientId }) {
  const a = await sshExec({ host, privateKey: key, cmd: `kubectl label node ${nodeName} client=${clientId} --overwrite`, timeoutMs: 20000 });
  const b = await sshExec({ host, privateKey: key, cmd: `kubectl taint node ${nodeName} client=${clientId}:NoSchedule --overwrite`, timeoutMs: 20000 });
  return { a, b };
}
