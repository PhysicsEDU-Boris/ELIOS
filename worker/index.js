// Holds the Gemini key for the app (decision 0179): the app POSTs a prompt and an optional photo with
// the student's Firebase ID token; this runs the 0176 fallback chain and returns the reply and the model.

import { generate } from './chain.js';
import { verifyIdToken } from './auth.js';

const reply = (data, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { 'content-type': 'application/json' } });

export async function handle(request, env, deps = {}) {
  if (request.method !== 'POST') return reply({ error: 'POST only' }, 405);
  const token = /^Bearer (.+)$/.exec(request.headers.get('authorization') ?? '')?.[1];
  if (!token || !(await verifyIdToken(token, env.FIREBASE_PROJECT_ID, deps))) {
    return reply({ error: 'Sign in first.' }, 401);
  }
  let body;
  try {
    body = await request.json();
  } catch {
    return reply({ error: 'body must be JSON' }, 400);
  }
  const { prompt, system, image, json } = body ?? {};
  if (typeof prompt !== 'string' || !prompt || prompt.length > 8000) {
    return reply({ error: 'prompt must be text up to 8000 characters' }, 400);
  }
  if (system != null && (typeof system !== 'string' || system.length > 2000)) {
    return reply({ error: 'system must be text up to 2000 characters' }, 400);
  }
  if (image != null && (typeof image !== 'string' || image.length > 2000000)) {
    return reply({ error: 'image must be base64 JPEG up to 1.5 MB' }, 400);
  }
  const out = await generate({ key: env.GEMINI_API_KEY, prompt, system, image, json: json === true });
  return out ? reply(out) : reply({ error: 'Every Gemini model is busy or capped right now.' }, 503);
}

export default { fetch: (request, env) => handle(request, env) };
