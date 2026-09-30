import crypto from 'crypto';

const COOKIE = 'nathoeng_account_session';

function decode(value) {
  let b = value.replace(/-/g, '+').replace(/_/g, '/');
  while (b.length % 4) b += '=';
  return Buffer.from(b, 'base64').toString();
}
function sign(value, secret) {
  return crypto.createHmac('sha256', secret).update(value).digest('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}
function verify(token) {
  const secret = process.env.ACCOUNT_BRIDGE_KEY;
  if (!secret || !token) return null;
  const parts = token.split('.');
  if (parts.length !== 2) return null;
  const expected = sign(parts[0], secret);
  const a = Buffer.from(parts[1]), b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  try {
    const data = JSON.parse(decode(parts[0]));
    if (data.role !== 'admin' || !data.exp || Date.now() > data.exp) return null;
    return data;
  } catch { return null; }
}
function makeSession(source) {
  const payload = Buffer.from(JSON.stringify({
    memberId: source.memberId,
    adminName: source.adminName || null,
    role: 'admin',
    purpose: 'account-session',
    exp: Date.now() + 4 * 60 * 60 * 1000
  })).toString('base64').replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/g,'');
  return payload + '.' + sign(payload, process.env.ACCOUNT_BRIDGE_KEY);
}
function cookieToken(req) {
  const raw = String(req.headers.cookie || '').split(';').map(x=>x.trim())
    .find(x=>x.startsWith(COOKIE + '='));
  return raw ? decodeURIComponent(raw.slice(COOKIE.length + 1)) : '';
}
export default function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method === 'POST') {
    const token = String(req.body?.token || '');
    const session = verify(token);
    if (!session) return res.status(403).send('Admin permission required');
    const accountSession = makeSession(session);
    res.setHeader('Set-Cookie', COOKIE + '=' + encodeURIComponent(accountSession) + '; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=14400');
    res.statusCode = 303;
    res.setHeader('Location', '/');
    return res.end();
  }
  if (req.method === 'GET') {
    const session = verify(cookieToken(req));
    if (!session) return res.status(403).json({ success:false });
    return res.status(200).json({ success:true, admin:{ memberId:session.memberId, name:session.adminName || null, role:session.role } });
  }
  return res.status(405).json({ success:false });
}