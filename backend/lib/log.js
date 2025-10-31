// backend/src/lib/log.js
export function log(evt, meta = {}) {
    const ts = new Date().toISOString();
    try {
      console.log(`${ts} ${evt} ${JSON.stringify(meta)}`);
    } catch {
      console.log(`${ts} ${evt}`);
    }
  }
  