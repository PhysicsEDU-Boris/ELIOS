// Firebase ID token check (RS256 JWT, Firebase's "verify ID tokens with a third-party library" rules),
// so only signed-in ELIOS users (guests included) can spend the Gemini key.

const JWKS = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
let cache = { keys: null, until: 0 };

async function googleKeys(fetchFn, now) {
  if (cache.keys && cache.until > now) return cache.keys;
  const res = await fetchFn(JWKS);
  if (!res.ok) throw new Error(`jwks HTTP ${res.status}`);
  const maxAge = Number(/max-age=(\d+)/.exec(res.headers.get('cache-control') ?? '')?.[1] ?? 3600);
  cache = { keys: (await res.json()).keys, until: now + maxAge * 1000 };
  return cache.keys;
}

const b64url = (s) => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));
const jsonPart = (s) => JSON.parse(new TextDecoder().decode(b64url(s)));

/** The token's claims when it is a valid, unexpired Firebase ID token for [projectId]; otherwise null. */
export async function verifyIdToken(token, projectId, { fetch: fetchFn = globalThis.fetch, now = Date.now(), keys } = {}) {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  try {
    const header = jsonPart(parts[0]);
    const claims = jsonPart(parts[1]);
    if (header.alg !== 'RS256') return null;
    const jwk = (keys ?? (await googleKeys(fetchFn, now))).find((k) => k.kid === header.kid);
    if (!jwk) return null;
    const key = await crypto.subtle.importKey('jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
    const signed = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, b64url(parts[2]),
      new TextEncoder().encode(`${parts[0]}.${parts[1]}`));
    const t = now / 1000;
    if (!signed || claims.aud !== projectId || claims.iss !== `https://securetoken.google.com/${projectId}`
        || !claims.sub || !(claims.exp > t) || !(claims.iat <= t + 300)) return null;
    return claims;
  } catch {
    return null;
  }
}
