'use strict';
// Holds the Gemini key for the app (decision 0179): the app sends a prompt and an optional photo,
// this runs the 0176 fallback chain and returns the reply and the model that gave it.

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { generate } = require('./chain');

const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');

exports.eliosAi = onCall({
  region: 'asia-southeast2',
  secrets: [GEMINI_API_KEY],
  timeoutSeconds: 60,
  memory: '256MiB',
  maxInstances: 1, // one instance (80 concurrent calls) so the chain's rest times are shared
}, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const { prompt, system, image, json } = req.data ?? {};
  if (typeof prompt !== 'string' || !prompt || prompt.length > 8000) {
    throw new HttpsError('invalid-argument', 'prompt must be text up to 8000 characters');
  }
  if (system != null && (typeof system !== 'string' || system.length > 2000)) {
    throw new HttpsError('invalid-argument', 'system must be text up to 2000 characters');
  }
  if (image != null && (typeof image !== 'string' || image.length > 2000000)) {
    throw new HttpsError('invalid-argument', 'image must be base64 JPEG up to 1.5 MB');
  }
  const out = await generate({ key: GEMINI_API_KEY.value(), prompt, system, image, json: json === true });
  if (!out) throw new HttpsError('unavailable', 'Every Gemini model is busy or capped right now.');
  return out;
});
