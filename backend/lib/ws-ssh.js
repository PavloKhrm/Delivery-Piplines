import { WebSocketServer } from "ws";
import fs from "fs";
import { Client as SSHClient } from "ssh2";
import * as hc from "./hetzner.js";

export function attachSshWs(server) {
  if (!server) return;

  const wss = new WebSocketServer({ noServer: true });

  server.on("upgrade", (req, socket, head) => {
    try {
      const url = req.url || "";
      if (!url.startsWith("/ws/ssh")) return;
      wss.handleUpgrade(req, socket, head, (ws) => {
        wss.emit("connection", ws, req);
      });
    } catch {
      try { socket.destroy(); } catch {}
    }
  });

  wss.on("connection", (ws) => {
    let conn = null;
    let sh = null;

    ws.on("message", (data) => {
      let msg = null;
      try { msg = JSON.parse(String(data)); } catch {}
      if (!msg || typeof msg !== "object") return;

      if (msg.type === "start") {
        const serverId = String(msg.serverId || "").trim();
        const cols = Number(msg.cols || 120);
        const rows = Number(msg.rows || 30);
        startSession(ws, serverId, cols, rows);
      } else if (msg.type === "data") {
        if (sh) try { sh.write(msg.data); } catch {}
      } else if (msg.type === "resize") {
        if (sh && msg.cols && msg.rows) {
          try { sh.setWindow(msg.rows, msg.cols, 600, 400); } catch {}
        }
      }
    });

    ws.on("close", () => {
      try { sh && sh.close(); } catch {}
      try { conn && conn.end(); } catch {}
      conn = null; sh = null;
    });

    async function startSession(ws, serverId, cols, rows) {
      try {
        const srv = await findServer(serverId);
        if (!srv || !srv.ip) return wsSend(ws, { type: "error", message: "server not found" });

        const keyPath = hc.getPrivateKeyFileByServerId(String(serverId));
        if (!keyPath) return wsSend(ws, { type: "error", message: "key not found" });

        const privateKey = fs.readFileSync(keyPath, "utf8");

        conn = new SSHClient();
        conn
          .on("ready", () => {
            wsSend(ws, { type: "ready" });
            conn.shell({ cols, rows, term: "xterm-256color" }, (err, stream) => {
              if (err) {
                wsSend(ws, { type: "error", message: String(err.message || err) });
                try { conn.end(); } catch {}
                return;
              }
              sh = stream;
              sh.on("data", (chunk) => wsSend(ws, { type: "data", data: chunk.toString("utf8") }));
              sh.on("close", () => { wsSend(ws, { type: "exit" }); try { conn.end(); } catch {} });
            });
          })
          .on("error", (e) => {
            wsSend(ws, { type: "error", message: String(e.message || e) });
          })
          .connect({ host: srv.ip, username: "root", privateKey, readyTimeout: 20000 });
      } catch (e) {
        wsSend(ws, { type: "error", message: String(e.message || e) });
      }
    }
  });
}

function wsSend(ws, obj) {
  try { ws.send(JSON.stringify(obj)); } catch {}
}

async function findServer(id) {
  try {
    const list = await hc.listServers();
    return (list || []).find((s) => String(s.id) === String(id)) || null;
  } catch { return null; }
}
