// ssh.js
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { execFileSync } from "child_process";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export function genOpenSSHKeyPair(comment = "client") {
  const keysDir = path.join(__dirname, "keys");
  if (!fs.existsSync(keysDir)) fs.mkdirSync(keysDir, { recursive: true });

  const baseName = `${comment}-${Date.now()}`;
  const keyPath = path.join(keysDir, baseName); 

  execFileSync("ssh-keygen", ["-t", "ed25519", "-C", comment, "-f", keyPath, "-N", ""], {
    stdio: "ignore",
  });

  const privateKey = fs.readFileSync(keyPath, "utf8");
  const publicKey = fs.readFileSync(`${keyPath}.pub`, "utf8");

  const privateKeyFile = `${keyPath}.key`;
  fs.writeFileSync(privateKeyFile, privateKey, { mode: 0o600 });

  return { publicKey, privateKey, privateKeyFile, baseName, keyPath };
}
