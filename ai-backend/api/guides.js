import { handleGuides } from '../guides.js';
export const POST = (request) => handleGuides(request, {
  FIREBASE_PROJECT_ID: process.env.FIREBASE_PROJECT_ID ?? 'elio-apps',
  GEMINI_API_KEY: process.env.GEMINI_API_KEY,
  SUPABASE_SECRET_KEY: process.env.SUPABASE_SECRET_KEY,
  SUPABASE_URL: process.env.SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
});
