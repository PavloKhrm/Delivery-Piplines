import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { execFileSync } from "child_process";
import { Client as SSHClient } from "ssh2";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export function genOpenSSHKeyPair(comment = "client") {
  const keysDir = path.join(__dirname, "keys");
  if (!fs.existsSync(keysDir)) fs.mkdirSync(keysDir, { recursive: true });
  const baseName = `${comment}-${Date.now()}`;
  const keyPath = path.join(keysDir, baseName);
  execFileSync("ssh-keygen", ["-t", "ed25519", "-C", comment, "-f", keyPath, "-N", ""], { stdio: "ignore" });
  const privateKey = fs.readFileSync(keyPath, "utf8");
  const publicKey = fs.readFileSync(`${keyPath}.pub`, "utf8");
  const privateKeyFile = `${keyPath}.key`;
  fs.writeFileSync(privateKeyFile, privateKey, { mode: 0o600 });
  return { publicKey, privateKey, privateKeyFile, baseName, keyPath };
}

export function sshExec({ host, username = "root", privateKey, cmd, timeoutMs = 60000 }) {
  return new Promise((resolve, reject) => {
    const conn = new SSHClient();
    let timer = setTimeout(() => {
      try { conn.end(); } catch {}
      reject(new Error("ssh timeout"));
    }, timeoutMs);
    let stdout = "";
    let stderr = "";
    conn.on("ready", () => {
      conn.exec(cmd, (err, stream) => {
        if (err) {
          clearTimeout(timer);
          try { conn.end(); } catch {}
          reject(err);
          return;
        }
        stream.on("data", d => { stdout += d.toString(); });
        stream.stderr.on("data", d => { stderr += d.toString(); });
        stream.on("close", (code) => {
          clearTimeout(timer);
          try { conn.end(); } catch {}
          resolve({ code, stdout, stderr });
        });
      });
    }).on("error", (e) => {
      clearTimeout(timer);
      reject(e);
    }).connect({ host, username, privateKey, port: 22, readyTimeout: 20000, keepaliveInterval: 10000 });
  });
}

export async function waitForSSH({ host, privateKey, attempts = 30, intervalMs = 5000 }) {
  for (let i = 1; i <= attempts; i++) {
    try {
      const r = await sshExec({ host, privateKey, cmd: "echo ok", timeoutMs: 15000 });
      if (/ok/.test(r.stdout)) return true;
    } catch {}
    await new Promise(r => setTimeout(r, intervalMs));
  }
  return false;
}
