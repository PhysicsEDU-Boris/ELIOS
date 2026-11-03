// Gemini fallback chain and switch rules from decision 0176.

const API = 'https://generativelanguage.googleapis.com/v1beta/models';
export const CHAIN = [
  'gemini-3.5-flash-lite',
  'gemini-3.1-flash-lite',
  'gemini-3-flash-preview',
  'gemini-3.6-flash',
  'gemini-robotics-er-2-preview',
];
const TIMEOUT_MS = 8000;
const REST_MS = 60000;

// Model -> epoch ms until which it is skipped (Infinity: dropped after a 404).
// ponytail: per function instance, forgotten on a cold start; move to a store if 429s repeat.
export const restUntil = new Map();

/** Next midnight in America/Los_Angeles, when the free daily caps reset (15:00 WIB). */
export function nextPacificMidnight(now) {
  const la = new Date(new Date(now).toLocaleString('en-US', { timeZone: 'America/Los_Angeles' }));
  const offset = now - la.getTime();
  la.setHours(24, 0, 0, 0);
  return la.getTime() + offset;
}

function restAfter429(body, now) {
  if (body.includes('PerDay')) return nextPacificMidnight(now);
  const delay = /"retryDelay":\s*"(\d+(?:\.\d+)?)s"/.exec(body);
  return now + (delay ? Number(delay[1]) * 1000 : REST_MS);
}

function replyText(body) {
  try {
    const parts = JSON.parse(body).candidates?.[0]?.content?.parts ?? [];
    return parts.filter((p) => !p.thought).map((p) => p.text ?? '').join('').trim();
  } catch {
    return '';
  }
}

function isJson(text) {
  try {
    JSON.parse(text.replace(/^```(?:json)?\s*|\s*```$/g, ''));
    return true;
  } catch {
    return false;
  }
}

/**
 * Tries each chain model in order. Returns {text, model, ms, tried} from the first good reply,
 * or null when every model is resting, failing or capped (the app then uses the question bank).
 */
export async function generate({ key, prompt, system, image, json }, { fetch = globalThis.fetch, now = Date.now, log = console.log } = {}) {
  const body = JSON.stringify({
    contents: [{
      role: 'user',
      parts: [...(image ? [{ inlineData: { mimeType: 'image/jpeg', data: image } }] : []), { text: prompt }],
    }],
    generationConfig: {
      thinkingConfig: { thinkingLevel: 'minimal' }, // every chain model accepted it in the 0176 run
      ...(json ? { responseMimeType: 'application/json' } : {}),
    },
    ...(system ? { systemInstruction: { parts: [{ text: system }] } } : {}),
  });
  const tried = [];
  for (const model of CHAIN) {
    if ((restUntil.get(model) ?? 0) > now()) continue;
    // A second attempt only follows an empty or invalid-JSON reply.
    for (let attempt = 0; attempt < 2; attempt++) {
      const start = now();
      let status;
      let text;
      try {
        const res = await fetch(`${API}/${model}:generateContent`, {
          method: 'POST',
          headers: { 'x-goog-api-key': key, 'Content-Type': 'application/json' },
          body,
          signal: AbortSignal.timeout(TIMEOUT_MS),
        });
        status = res.status;
        text = await res.text();
      } catch (e) {
        status = 599; // timeout or network error: handled like a 5xx
        text = String(e);
      }
      tried.push(`${model}:${status}`);
      if (status === 200) {
        const reply = replyText(text);
        if (!reply || (json && !isJson(reply))) continue;
        const ms = now() - start;
        log(`eliosAi answered by ${model} in ${ms} ms (tried ${tried.join(', ')})`);
        return { text: reply, model, ms, tried };
      }
      if (status === 400) log(`eliosAi ${model} 400: ${text.slice(0, 300)}`); // request or location problem, not a cap
      if (status === 429) restUntil.set(model, restAfter429(text, now()));
      else if (status === 404) restUntil.set(model, Infinity);
      else if (status >= 500) restUntil.set(model, now() + REST_MS);
      break;
    }
  }
  log(`eliosAi: no model answered (tried ${tried.join(', ') || 'none, all resting'})`);
  return null;
}
