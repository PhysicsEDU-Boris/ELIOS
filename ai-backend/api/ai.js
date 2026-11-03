// Vercel function (Node runtime, region sin1 in vercel.json): Gemini serves Singapore, while it
// refused many Cloudflare locations ("User location is not supported").
import { handle } from '../index.js';

export const POST = (request) => handle(request, {
  GEMINI_API_KEY: process.env.GEMINI_API_KEY,
  FIREBASE_PROJECT_ID: process.env.FIREBASE_PROJECT_ID ?? 'elio-apps',
});
