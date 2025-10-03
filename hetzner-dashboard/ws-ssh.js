// ws-ssh.js
import url from "url";
import fs from "fs";
import { WebSocketServer } from "ws";
import { Client as SSHClient } from "ssh2";
import * as hc from "./hetzner.js";

export function attachSshWs({ server, panelUser, panelPass }) {
  const wss = new WebSocketServer({ noServer: true });

  server.on("upgrade", (req, socket, head) => {
    const { pathname } = url.parse(req.url);
    if (pathname !== "/ws/ssh") {
      socket.destroy();
      return;
    }

    const auth = req.headers["authorization"] || "";
    if (!checkBasicAuth(auth, panelUser, panelPass)) {
      socket.destroy();
      return;
    }

    wss.handleUpgrade(req, socket, head, (ws) => {
      wss.emit("connection", ws, req);
    });
  });

  wss.on("connection", (ws) => {
    let conn = null;
    let stream = null;

    const safeSend = (obj) => {
      if (ws.readyState === ws.OPEN) {
        try { ws.send(JSON.stringify(obj)); } catch { /* noop */ }
      }
    };

    ws.on("message", async (raw) => {
      let msg;
      try { msg = JSON.parse(raw.toString()); } catch {
        safeSend({ type: "error", message: "Invalid JSON" });
        return;
      }

      if (msg.type === "start") {
        if (!msg.serverId) {
          safeSend({ type: "error", message: "serverId required" });
          return;
        }
        try {
          const { ip, key } = await resolveHostAndKey(msg.serverId);
          if (!ip || !key) {
            safeSend({ type: "error", message: "Cannot resolve IP or key" });
            return;
          }
          conn = new SSHClient();
          conn
            .on("ready", () => {
              conn.shell(
                { term: "xterm-256color", cols: msg.cols || 120, rows: msg.rows || 30 },
                (err, s) => {
                  if (err) {
                    safeSend({ type: "error", message: String(err.message || err) });
                    return;
                  }
                  stream = s;
                  safeSend({ type: "ready" });

                  stream.on("data", (d) => safeSend({ type: "data", data: d.toString("utf8") }));
                  stream.stderr?.on?.("data", (d) => safeSend({ type: "data", data: d.toString("utf8") }));
                  stream.on("close", () => {
                    safeSend({ type: "exit", code: 0 });
                    ws.close();
                  });
                }
              );
            })
            .on("error", (e) => {
              safeSend({ type: "error", message: String(e.message || e) });
              ws.close();
            })
            .connect({
              host: ip,
              port: 22,
              username: "root",
              privateKey: key,
              readyTimeout: 15000,
              keepaliveInterval: 10000,
            });
        } catch (e) {
          safeSend({ type: "error", message: String(e.message || e) });
        }
        return;
      }

      if (msg.type === "data") {
        if (stream) stream.write(msg.data);
        return;
      }

      if (msg.type === "resize") {
        if (stream && msg.cols && msg.rows) {
          try { stream.setWindow(msg.rows, msg.cols, 600, 400); } catch {}
        }
        return;
      }
    });

    ws.on("close", () => {
      try { stream?.end?.(); } catch {}
      try { conn?.end?.(); } catch {}
    });
  });
}

function checkBasicAuth(hdr, user, pass) {
  if (!hdr.startsWith("Basic ")) return false;
  const [u, p] = Buffer.from(hdr.split(" ")[1], "base64").toString().split(":");
  return u === user && p === pass;
}

async function resolveHostAndKey(serverId) {
  const servers = await hc.listServers();
  const target = servers.find((s) => String(s.id) === String(serverId));
  const ip = target?.ip || null;

  const key = await hc.getPrivateKey(String(serverId));
  return { ip, key };
}
