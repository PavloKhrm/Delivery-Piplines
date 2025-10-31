// backend/src/routes/hook.js
import express from "express";
import { rolloutAllNamespaces } from "../svc/rollout.js";
import { setApiTag, setWebTag, setBoth, getTags } from "../svc/tags.js";
import { listClusters, loadClusterMeta } from "../../lib/hetzner.js";

const router = express.Router();

const log = (evt, obj = {}) => console.log(new Date().toISOString(), "[hook]", evt, obj);

function parseDockerHub(body) {
  const repoName = body?.repository?.repo_name || "";
  const tag = body?.push_data?.tag || "";
  if (!repoName || !tag) return null;
  const [ns, name] = repoName.split("/");
  if (!ns || !name) return null;
  if (!/^client-(api|web)$/.test(name)) return null;
  return { ns, name, tag };
}

router.post("/hook/redeploy", async (req, res) => {
  const token = String(req.query.token || "");
  if (!token || token !== (process.env.WEBHOOK_TOKEN || "")) {
    return res.status(401).json({ ok: false, error: "bad token" });
  }

  try {
    const dh = parseDockerHub(req.body);

    if (dh) {
      if (dh.name === "client-api") setApiTag(dh.ns, dh.tag);
      if (dh.name === "client-web") setWebTag(dh.ns, dh.tag);
    } else {
      const repo = String(req.body.repo || "").trim();
      const apiTag = String(req.body.apiTag || "").trim();
      const webTag = String(req.body.webTag || "").trim();
      if (!repo || (!apiTag && !webTag)) {
        return res.status(400).json({ ok: false, error: "repo and at least one tag required" });
      }
      if (apiTag && webTag) setBoth(repo, apiTag, webTag);
      else if (apiTag) setApiTag(repo, apiTag);
      else if (webTag) setWebTag(repo, webTag);
    }

    const { repo, apiTag, webTag } = getTags();
    log("redeploy.start", { repo, apiTag, webTag, ip: req.ip });

    const clusters = listClusters();
    for (const c of clusters) {
      const meta = loadClusterMeta(String(c.clusterId));
      if (!meta?.ip) continue;
      await rolloutAllNamespaces({ cpIp: meta.ip, repo, apiTag, webTag });
    }

    log("redeploy.done", {});
    return res.json({ ok: true, repo, apiTag, webTag });
  } catch (e) {
    log("redeploy.err", { err: String(e?.message || e) });
    return res.status(500).json({ ok: false, error: String(e?.message || e) });
  }
});

export default router;
