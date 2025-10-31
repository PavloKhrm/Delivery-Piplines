// src/svc/tags.js
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DATA_DIR = path.join(__dirname, "..", "..", "data");
const FILE = path.join(DATA_DIR, "tags.json");

function ensure() {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
  if (!fs.existsSync(FILE)) fs.writeFileSync(FILE, JSON.stringify({ repo:"pavlokhar", apiTag:"latest", webTag:"latest" }, null, 2));
}
export function getTags() {
  ensure();
  return JSON.parse(fs.readFileSync(FILE, "utf8"));
}
export function setApiTag(repo, tag) {
  ensure();
  const cur = getTags();
  fs.writeFileSync(FILE, JSON.stringify({ repo, apiTag: tag, webTag: cur.webTag }, null, 2));
}
export function setWebTag(repo, tag) {
  ensure();
  const cur = getTags();
  fs.writeFileSync(FILE, JSON.stringify({ repo, apiTag: cur.apiTag, webTag: tag }, null, 2));
}
export function setBoth(repo, apiTag, webTag) {
  ensure();
  fs.writeFileSync(FILE, JSON.stringify({ repo, apiTag, webTag }, null, 2));
}
