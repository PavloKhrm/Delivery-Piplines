// backend/src/middleware/auth.js
export default function authBasic({ user, pass, bypass = [] }) {
  const allowed = new Set(['/api/hook/redeploy', '/healthz', ...bypass]);
  return (req, res, next) => {
    const full = `${req.baseUrl || ''}${req.path || req.url || ''}`;
    for (const p of allowed) if (full.startsWith(p)) return next();
    const hdr = String(req.headers.authorization || '');
    if (!hdr.startsWith('Basic ')) return challenge(res);
    const [u, p] = Buffer.from(hdr.split(' ')[1], 'base64').toString().split(':');
    if (u === user && p === pass) return next();
    return challenge(res);
  };
  function challenge(res) {
    res.set('WWW-Authenticate', 'Basic realm="Dashboard"');
    res.status(401).send('Auth required');
  }
}
