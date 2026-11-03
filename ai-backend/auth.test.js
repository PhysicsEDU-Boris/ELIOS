import test from 'node:test';
import assert from 'node:assert';
import { verifyIdToken } from './auth.js';
import { handle } from './index.js';

const project = 'elio-apps';
const now = 1_800_000_000_000;
const pair = await crypto.subtle.generateKey(
  { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
  true, ['sign', 'verify']);
const keys = [{ ...(await crypto.subtle.exportKey('jwk', pair.publicKey)), kid: 'k1', alg: 'RS256', use: 'sig' }];

const b64 = (bytes) => Buffer.from(bytes).toString('base64url');
async function token(claims = {}, { kid = 'k1', key = pair.privateKey } = {}) {
  const t = now / 1000;
  const head = b64(JSON.stringify({ alg: 'RS256', kid }));
  const body = b64(JSON.stringify({
    aud: project, iss: `https://securetoken.google.com/${project}`, sub: 'u1', iat: t - 10, exp: t + 3600, ...claims,
  }));
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${head}.${body}`));
  return `${head}.${body}.${b64(new Uint8Array(sig))}`;
}
const check = async (t) => verifyIdToken(t, project, { keys, now });

test('a valid Firebase ID token passes', async () => {
  assert.equal((await check(await token())).sub, 'u1');
});

test('wrong project, wrong issuer, expired, no user or unknown key are refused', async () => {
  assert.equal(await check(await token({ aud: 'other' })), null);
  assert.equal(await check(await token({ iss: 'https://evil.example' })), null);
  assert.equal(await check(await token({ exp: now / 1000 - 1 })), null);
  assert.equal(await check(await token({ sub: '' })), null);
  assert.equal(await check(await token({}, { kid: 'nope' })), null);
});

test('a token signed with another key, or edited after signing, is refused', async () => {
  const other = await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true, ['sign', 'verify']);
  assert.equal(await check(await token({}, { key: other.privateKey })), null);
  const [h, , s] = (await token()).split('.');
  const forged = b64(JSON.stringify({ aud: project, iss: `https://securetoken.google.com/${project}`, sub: 'x', iat: 0, exp: 9e9 }));
  assert.equal(await check(`${h}.${forged}.${s}`), null);
  assert.equal(await check('not.a.token'), null);
});

test('the backend refuses calls without a valid token before spending the key', async () => {
  const env = { FIREBASE_PROJECT_ID: project, GEMINI_API_KEY: 'k' };
  const post = (headers) => new Request('https://w/', { method: 'POST', headers, body: '{"prompt":"p"}' });
  assert.equal((await handle(post({}), env, { keys, now })).status, 401);
  assert.equal((await handle(post({ authorization: 'Bearer junk' }), env, { keys, now })).status, 401);
  assert.equal((await handle(new Request('https://w/'), env)).status, 405);
  const bad = new Request('https://w/', { method: 'POST', headers: { authorization: `Bearer ${await token()}` }, body: '{}' });
  assert.equal((await handle(bad, env, { keys, now })).status, 400);
});
