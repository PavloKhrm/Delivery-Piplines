import { Router } from "express";
import * as hc from "../../lib/hetzner.js";
import { DEF_API, DEF_WEB, DEF_API_PORT, DEF_WEB_PORT } from "../config.js";
const r = Router();
r.get("/meta", async (_req, res) => {
  try {
    const [types, locations, images] = await Promise.all([hc.listServerTypes(), hc.listLocations(), hc.listSystemImages()]);
    res.json({ ok: true, types, locations, images, defaults: { cluster: {}, client: {}, images: { api: DEF_API, web: DEF_WEB, apiPort: DEF_API_PORT, webPort: DEF_WEB_PORT } } });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e.message || e) });
  }
});
export default r;
