import { createHash } from 'node:crypto';
import { verifyIdToken } from './auth.js';

const reply = (data, status = 200) => new Response(JSON.stringify(data), {
  status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
});
const validId = (id) => typeof id === 'string' && /^[a-zA-Z0-9_-]{1,100}$/.test(id);
const publicId = (uid, id) => `elios-scans/${createHash('sha256').update(uid).digest('hex')}/${id}`;
const signature = (params, secret) => createHash('sha256').update(
  Object.keys(params).sort().map(k => `${k}=${params[k]}`).join('&') + secret).digest('hex');

export async function handleHistory(request, env, deps = {}) {
  const fetchFn = deps.fetch ?? fetch;
  if (request.method !== 'POST') return reply({ error: 'POST only' }, 405);
  const token = /^Bearer (.+)$/.exec(request.headers.get('authorization') ?? '')?.[1];
  const claims = token && await (deps.verify ?? verifyIdToken)(token, env.FIREBASE_PROJECT_ID);
  if (!claims || typeof claims.sub !== 'string') return reply({ error: 'Sign in first' }, 401);
  const databaseKey = env.SUPABASE_SECRET_KEY ?? env.SUPABASE_SERVICE_ROLE_KEY;
  if (!env.SUPABASE_URL || !databaseKey) return reply({ error: 'History cloud is not configured' }, 503);
  let body;
  try {
    const text = await request.text();
    if (Buffer.byteLength(text) > 3000000) return reply({ error: 'Request too large' }, 413);
    body = JSON.parse(text);
  } catch { return reply({ error: 'Invalid JSON' }, 400); }
  if (!body || typeof body !== 'object') return reply({ error: 'Invalid request' }, 400);
  const { op, id } = body;
  if (!['list', 'save', 'uploadPhoto', 'photo'].includes(op)) return reply({ error: 'Unknown operation' }, 400);
  if (op !== 'list' && !validId(id)) return reply({ error: 'Invalid scan ID' }, 400);
  const db = async (path, options = {}) => {
    const response = await fetchFn(`${env.SUPABASE_URL}/rest/v1/${path}`, {
      ...options, headers: { apikey: databaseKey,
        ...(!databaseKey.startsWith('sb_secret_') ? { authorization: `Bearer ${databaseKey}` } : {}), 'content-type': 'application/json', ...options.headers },
      signal: AbortSignal.timeout(20000),
    });
    if (!response.ok) throw new Error('History database unavailable');
    const text = await response.text();
    return text ? JSON.parse(text) : null;
  };
  const query = new URLSearchParams({ owner_id: `eq.${claims.sub}` });
  try {
    if (op === 'list') {
      const cursor = body.cursor;
      if (cursor != null) {
        if (typeof cursor.time !== 'string' || !/^\d{4}-\d\d-\d\dT[0-9:.]+(?:Z|\+00:00)$/.test(cursor.time)
            || !Number.isFinite(Date.parse(cursor.time)) || !validId(cursor.id)) {
          return reply({ error: 'Invalid cursor' }, 400);
        }
        query.set('or', `(updated_at.gt.${cursor.time},and(updated_at.eq.${cursor.time},id.gt.${cursor.id}))`);
      }
      query.set('select', 'id,data,has_photo,updated_at');
      query.set('order', 'updated_at.asc,id.asc'); query.set('limit', '100');
      return reply({ records: await db(`scan_history?${query}`) });
    }
    if (op === 'save') {
      const d = body.data;
      if (!d || d.id !== id || typeof d.itemName !== 'string' || d.itemName.length > 500
          || !['organic', 'recyclable', 'b3', 'residu'].includes(d.category)
          || typeof d.time !== 'string' || !Number.isFinite(Date.parse(d.time))
          || !Array.isArray(d.questions) || d.questions.length < 1 || d.questions.length > 10
          || !['id', 'en'].includes(d.lang) || JSON.stringify(d).length > 250000
          || !Number.isInteger(d.trophies) || d.trophies < 0
          || d.questions.some(q => !q || typeof q.question !== 'string' || typeof q.yourAnswer !== 'string'
            || typeof q.rightAnswer !== 'string' || typeof q.isCorrect !== 'boolean')) {
        return reply({ error: 'Invalid record' }, 400);
      }
      const { cropPhotoPath, ...data } = d; // Local paths never leave the owner's device.
      await db('rpc/save_scan', { method: 'POST', body: JSON.stringify({ p_owner: claims.sub, p_id: id, p_data: data }) });
      return reply({ ok: true });
    }
    query.set('id', `eq.${id}`); query.set('select', 'has_photo');
    const rows = await db(`scan_history?${query}`);
    if (!rows?.length) return reply({ error: 'Scan not found' }, 404);
    if (!env.CLOUDINARY_CLOUD_NAME || !env.CLOUDINARY_API_KEY || !env.CLOUDINARY_API_SECRET) {
      return reply({ error: 'Photo cloud is not configured' }, 503);
    }
    const cloud = `https://api.cloudinary.com/v1_1/${encodeURIComponent(env.CLOUDINARY_CLOUD_NAME)}/image`;
    if (op === 'uploadPhoto') {
      if (typeof body.image !== 'string' || body.image.length > 2000000 || !/^[A-Za-z0-9+/]+={0,2}$/.test(body.image)) {
        return reply({ error: 'Invalid photo' }, 400);
      }
      const bytes = Buffer.from(body.image, 'base64');
      if (bytes[0] !== 255 || bytes[1] !== 216 || bytes[2] !== 255) return reply({ error: 'JPEG required' }, 400);
      const params = { public_id: publicId(claims.sub, id), timestamp: Math.floor(Date.now()/1000), type: 'authenticated', overwrite: 'true' };
      const form = new FormData();
      for (const [k,v] of Object.entries(params)) form.set(k, `${v}`);
      form.set('api_key', env.CLOUDINARY_API_KEY);
      form.set('signature', signature(params, env.CLOUDINARY_API_SECRET));
      form.set('file', `data:image/jpeg;base64,${body.image}`);
      const upload = await fetchFn(`${cloud}/upload`, { method: 'POST', body: form, signal: AbortSignal.timeout(20000) });
      if (!upload.ok) throw new Error('Photo upload unavailable');
      await db(`scan_history?${query}`, { method: 'PATCH', body: JSON.stringify({ has_photo: true }) });
      return reply({ ok: true });
    }
    if (!rows[0].has_photo) return reply({ error: 'Photo not found' }, 404);
    const params = { public_id: publicId(claims.sub, id), format: 'jpg', type: 'authenticated',
      timestamp: Math.floor(Date.now()/1000), expires_at: Math.floor(Date.now()/1000)+60 };
    const download = new URL(`${cloud}/download`);
    for (const [k,v] of Object.entries(params)) download.searchParams.set(k, `${v}`);
    download.searchParams.set('api_key', env.CLOUDINARY_API_KEY);
    download.searchParams.set('signature', signature(params, env.CLOUDINARY_API_SECRET));
    const photo = await fetchFn(download, { signal: AbortSignal.timeout(20000) });
    if (!photo.ok) throw new Error('Photo download unavailable');
    return reply({ image: Buffer.from(await photo.arrayBuffer()).toString('base64') });
  } catch {
    return reply({ error: 'Cloud unavailable. Your local history is kept.' }, 503);
  }
}
