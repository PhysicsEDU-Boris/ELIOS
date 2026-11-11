// Daily Guide progress (decision 0194): stop XP, quiz grading, mini lab check and streaks.
// Same pattern as history.js (0191): the Firebase token gives the owner, Supabase is reached
// only with the server key, and the published guide JSON (never the client) holds the answers.

import { createHmac, timingSafeEqual } from 'node:crypto';
import { verifyIdToken } from './auth.js';
import { generate } from './chain.js';

export const XP = { story: 10, physics: 20, quiz: 10, lab: 20 };
const PAGES = 'https://physicsedu-boris.github.io/elios-guides/';
const DAY = /^\d{4}-\d\d-\d\d$/;
const ID = /^[A-Za-z0-9_-]{8,64}$/;
const LAB_PER_DAY = 5;
const MAX_BODY = 2 * 1024 * 1024;

const reply = (data, status = 200) => new Response(JSON.stringify(data), {
  status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
});
/** Asia/Jakarta calendar day (UTC+7, no DST) of an epoch ms. */
export const jakartaDay = (ms) => new Date(ms + 7 * 3600e3).toISOString().slice(0, 10);
const addDays = (day, n) => new Date(Date.parse(`${day}T00:00:00Z`) + n * 864e5).toISOString().slice(0, 10);
const xpOf = (stops) => Object.keys(stops ?? {}).reduce((sum, k) => sum + (XP[k] ?? 0), 0);

// ponytail: per function instance, like chain.js restUntil; a cold start just refetches from Pages.
const cache = { manifest: null, at: 0, content: new Map() };
export const resetCaches = () => { cache.manifest = null; cache.at = 0; cache.content.clear(); };

async function getJson(fetchFn, url) {
  const res = await fetchFn(url, { signal: AbortSignal.timeout(10000) });
  if (!res.ok) throw new Error(`guides HTTP ${res.status}`);
  return res.json();
}

async function manifest(fetchFn, now) {
  if (!cache.manifest || now - cache.at > 60000) {
    cache.manifest = await getJson(fetchFn, `${PAGES}manifest.json`);
    cache.at = now;
  }
  return Array.isArray(cache.manifest?.guides) ? cache.manifest.guides : [];
}

/** Published content JSON for [date] in [lang] (English when that language is missing), cached by revision. */
async function content(fetchFn, now, date, lang) {
  const guide = (await manifest(fetchFn, now)).find((g) => g?.date === date);
  const path = guide?.content?.[lang] ?? guide?.content?.en;
  if (typeof path !== 'string' || !new RegExp(`^issues/${date}/[A-Za-z0-9_-]+\\.json$`).test(path)) return null;
  const key = `${path}@${guide.revision ?? ''}@${guide.content_sha?.[lang] ?? ''}`;
  if (!cache.content.has(key)) cache.content.set(key, await getJson(fetchFn, PAGES + path));
  return cache.content.get(key);
}

/** Grades quiz answers against the published content; null when a question does not exist. */
export function grade(c, answers) {
  const results = answers.map(({ qid, choice }) => {
    const printed = /^p([1-3])$/.exec(qid)?.[1];
    const pool = /^pool-(\d{1,2})$/.exec(qid)?.[1];
    let answer;
    let explanation = null;
    if (printed) {
      answer = c._answers?.[printed];
      const question = c[`quiz.${printed}.question`];
      explanation = c._quiz_explain?.[printed]?.why
        ?? c._quiz_pool?.find((q) => q?.question === question)?.explanation ?? null;
    } else if (pool) {
      const item = c._quiz_pool?.[Number(pool)];
      answer = Number.isInteger(item?.answer) ? 'abcd'[item.answer] : undefined;
      explanation = item?.explanation ?? null;
    }
    if (!['a', 'b', 'c', 'd'].includes(answer)) return null;
    const wrong = printed && choice !== answer ? c._quiz_explain?.[printed]?.wrong?.[choice] ?? null : null;
    return { qid, correct: choice === answer, answer, explanation, wrong };
  });
  return results.includes(null) ? null : results;
}

/** Strict lab verdict from the model reply; approval needs every checklist item. */
export function parseVerdict(text, items) {
  let v;
  try { v = JSON.parse(String(text).replace(/^```(?:json)?\s*|\s*```$/g, '')); } catch { return null; }
  if (!v || !['approved', 'retry', 'teacher'].includes(v.verdict)
      || typeof v.reason_en !== 'string' || typeof v.reason_id !== 'string'
      || !Array.isArray(v.checklist) || v.checklist.length !== items
      || v.checklist.some((b) => typeof b !== 'boolean')) return null;
  const verdict = v.verdict === 'approved' && v.checklist.includes(false) ? 'retry' : v.verdict;
  return { verdict, reason_en: v.reason_en.slice(0, 400), reason_id: v.reason_id.slice(0, 400), checklist: v.checklist };
}

/**
 * Streak in Asia/Jakarta days: a day counts when a stop was finished on it; a day without a
 * published issue never breaks it (pipeline outages must not punish students). Today still open.
 */
export function streakOf(rows, published, today) {
  const active = new Set(rows.flatMap((r) => Object.values(r.stops ?? {})
    .filter((t) => typeof t === 'string' && Number.isFinite(Date.parse(t))).map((t) => jakartaDay(Date.parse(t)))));
  const issues = new Set(published);
  const first = [...active].sort()[0];
  let streak = 0;
  for (let d = active.has(today) ? today : addDays(today, -1); first && d >= first; d = addDays(d, -1)) {
    if (active.has(d)) streak++;
    else if (issues.has(d)) break;
  }
  let best = 0;
  for (let d = first, run = 0; first && d <= today; d = addDays(d, 1)) {
    if (active.has(d)) best = Math.max(best, ++run);
    else if (issues.has(d) && d !== today) run = 0;
  }
  const monday = addDays(today, -((new Date(`${today}T00:00:00Z`).getUTCDay() + 6) % 7));
  const week = Array.from({ length: 7 }, (_, i) => {
    const d = addDays(monday, i);
    const status = active.has(d) ? 'read' : d === today ? 'today' : d > today ? 'future' : issues.has(d) ? 'missed' : 'off';
    return { date: d, status };
  });
  return { streak, best_streak: best, week };
}

const LAB_SYSTEM = 'You check a school science mini lab from up to 8 still frames of a student\'s clip. '
  + 'Judge only what is visible. Reply with JSON only: {"verdict":"approved"|"retry"|"teacher",'
  + '"reason_en":string,"reason_id":string,"checklist":[boolean per item]}. approved = every item is clearly visible; '
  + 'retry = something is missing (say what to show, kindly, max 2 sentences, for a 12-year-old); '
  + 'teacher = unsafe or unclear content a teacher should see. reason_id is Bahasa Indonesia.';

export async function handleGuides(request, env, deps = {}) {
  const fetchFn = deps.fetch ?? fetch;
  const now = deps.now ?? Date.now;
  if (request.method !== 'POST') return reply({ error: 'POST only' }, 405);
  const verify = deps.verify ?? ((t) => verifyIdToken(t, env.FIREBASE_PROJECT_ID));
  const token = /^Bearer (.+)$/.exec(request.headers.get('authorization') ?? '')?.[1];
  const claims = token && await verify(token);
  if (!claims || typeof claims.sub !== 'string') return reply({ error: 'Sign in first' }, 401);
  const owner = claims.sub;
  const databaseKey = env.SUPABASE_SECRET_KEY ?? env.SUPABASE_SERVICE_ROLE_KEY;
  if (!env.SUPABASE_URL || !databaseKey) return reply({ error: 'Guide progress is not configured' }, 503);
  let body;
  try {
    const text = await request.text();
    if (Buffer.byteLength(text) > MAX_BODY) return reply({ error: 'Request too large' }, 413);
    body = JSON.parse(text);
  } catch { return reply({ error: 'Invalid JSON' }, 400); }
  if (!body || typeof body !== 'object') return reply({ error: 'Invalid request' }, 400);
  const { op, id, date } = body;
  if (!['progress', 'event', 'quiz', 'lab', 'review', 'import'].includes(op)) return reply({ error: 'Unknown operation' }, 400);
  if (['event', 'quiz', 'lab', 'review'].includes(op)
      && (!ID.test(id ?? '') || !DAY.test(date ?? '') || !Number.isFinite(Date.parse(date)))) {
    return reply({ error: 'Invalid id or date' }, 400);
  }
  const lang = body.lang === 'id' ? 'id' : 'en';
  // A guest keeps this on the phone; after signing in to another account it proves the old guest uid.
  const claimOf = (uid) => createHmac('sha256', databaseKey).update(`guest:${uid}`).digest('hex');

  const db = async (path, options = {}) => {
    const response = await fetchFn(`${env.SUPABASE_URL}/rest/v1/${path}`, {
      ...options, headers: { apikey: databaseKey,
        ...(!databaseKey.startsWith('sb_secret_') ? { authorization: `Bearer ${databaseKey}` } : {}),
        'content-type': 'application/json', ...options.headers },
      signal: AbortSignal.timeout(20000),
    });
    if (!response.ok) throw new Error('Guide database unavailable');
    const text = await response.text();
    return text ? JSON.parse(text) : null;
  };
  const q = (params) => new URLSearchParams({ owner_id: `eq.${owner}`, ...params });
  const rowsOf = async (who = owner) => await db(`guide_progress?${new URLSearchParams({ owner_id: `eq.${who}`, select: '*' })}`) ?? [];
  const save = (row) => db('guide_progress?on_conflict=owner_id,date', {
    method: 'POST', headers: { prefer: 'resolution=merge-duplicates' },
    body: JSON.stringify({ ...row, xp: xpOf(row.stops), updated_at: new Date(now()).toISOString() }),
  });
  const summary = async () => {
    const rows = await rowsOf();
    const published = (await manifest(fetchFn, now())).map((g) => g?.date).filter((d) => typeof d === 'string');
    const issues = Object.fromEntries(rows.map((r) => [r.date, { stops: r.stops ?? {}, quiz: r.quiz ?? {}, lab: r.lab ?? {}, xp: xpOf(r.stops) }]));
    return { issues, ...streakOf(rows, published, jakartaDay(now())), total_xp: rows.reduce((s, r) => s + xpOf(r.stops), 0),
      ...(claims.firebase?.sign_in_provider === 'anonymous' ? { guest_claim: claimOf(owner) } : {}) };
  };
  /** Claims the client's event id once; returns the updated row, or null for a repeat of the same id. */
  const record = async (type, update) => {
    const inserted = await db('guide_events?on_conflict=owner_id,id', {
      method: 'POST', headers: { prefer: 'resolution=ignore-duplicates,return=representation' },
      body: JSON.stringify({ owner_id: owner, id, date, type }),
    });
    if (!inserted?.length) return null;
    // ponytail: read-then-write; two different event ids for one stop racing could both see it unset,
    // but XP is recomputed from the stop map, so a race can never award a stop twice.
    const [row] = await db(`guide_progress?${q({ date: `eq.${date}`, select: '*' })}`) ?? [];
    const next = update(row ?? { owner_id: owner, date, stops: {}, quiz: {}, lab: {} });
    await save(next);
    return next;
  };
  const award = (row, stop) => (row.stops?.[stop] ? row
    : { ...row, stops: { ...row.stops, [stop]: new Date(now()).toISOString() } });

  try {
    if (op === 'progress') return reply(await summary());

    if (op === 'import') {
      const guest = body.guest_uid;
      const claim = typeof body.guest_claim === 'string' ? Buffer.from(body.guest_claim) : Buffer.alloc(0);
      if (typeof guest !== 'string' || guest === owner || claim.length !== 64
          || !timingSafeEqual(claim, Buffer.from(claimOf(guest)))) {
        return reply({ error: 'Only this phone\'s guest progress can be imported' }, 400);
      }
      const mine = new Map((await rowsOf()).map((r) => [r.date, r]));
      for (const g of await rowsOf(guest)) {
        const m = mine.get(g.date) ?? { owner_id: owner, date: g.date, stops: {}, quiz: {}, lab: {} };
        const stops = { ...g.stops };
        for (const [k, t] of Object.entries(m.stops ?? {})) if (!stops[k] || t < stops[k]) stops[k] = t;
        await save({ owner_id: owner, date: g.date, stops,
          quiz: Object.keys(m.quiz ?? {}).length ? m.quiz : g.quiz ?? {},
          lab: Object.keys(m.lab ?? {}).length ? m.lab : g.lab ?? {} });
      }
      return reply({ ok: true, progress: await summary() });
    }

    if (op === 'event') {
      const stop = { story_read: 'story', physics_read: 'physics' }[body.type];
      if (!stop) return reply({ error: 'Invalid event type' }, 400);
      if (!(await manifest(fetchFn, now())).some((g) => g?.date === date)) return reply({ error: 'Unknown issue' }, 404);
      const row = await record(body.type, (r) => award(r, stop));
      return reply({ ok: true, duplicate: !row, progress: await summary() });
    }

    if (op === 'quiz') {
      const answers = body.answers;
      if (!Array.isArray(answers) || answers.length !== 3
          || new Set(answers.map((a) => a?.qid)).size !== 3
          || answers.some((a) => typeof a?.qid !== 'string' || !['a', 'b', 'c', 'd'].includes(a?.choice))) {
        return reply({ error: 'Three answers required' }, 400);
      }
      const c = await content(fetchFn, now(), date, lang);
      if (!c) return reply({ error: 'Unknown issue' }, 404);
      const results = grade(c, answers);
      if (!results) return reply({ error: 'Unknown question' }, 400);
      const score = results.filter((r) => r.correct).length;
      const passed = score >= 2;
      let xp = 0;
      await record('quiz', (r) => {
        const next = passed ? award(r, 'quiz') : r;
        if (next !== r) xp = XP.quiz;
        const quiz = { attempts: (r.quiz?.attempts ?? 0) + 1, best: Math.max(score, r.quiz?.best ?? 0),
          first: r.quiz?.first ?? { score, answers: results.map(({ qid, correct }) => ({ qid, correct })) } };
        return { ...next, quiz };
      });
      return reply({ results, score, passed, xp_awarded: xp, progress: await summary() });
    }

    const [row] = await db(`guide_progress?${q({ date: `eq.${date}`, select: '*' })}`) ?? [];

    if (op === 'review') {
      const last = row?.lab?.last;
      if (!last) return reply({ error: 'No lab check to review' }, 404);
      await record('review', (r) => ({ ...r, lab: { ...r.lab, review_requested: new Date(now()).toISOString() } }))
        .then((r) => r && db('lab_reviews', { method: 'POST',
          body: JSON.stringify({ owner_id: owner, date, verdict: 'requested', reason: last.reason_en }) }));
      return reply({ ok: true, progress: await summary() });
    }

    // op === 'lab'
    const frames = body.frames;
    if (!Array.isArray(frames) || frames.length < 1 || frames.length > 8 || frames.some((f) => typeof f !== 'string'
        || !/^[A-Za-z0-9+/]+={0,2}$/.test(f) || !Buffer.from(f.slice(0, 8), 'base64').subarray(0, 3).equals(Buffer.from([255, 216, 255])))) {
      return reply({ error: 'Send 1 to 8 JPEG frames' }, 400);
    }
    const seen = await db(`guide_events?${q({ id: `eq.${id}`, select: 'id' })}`);
    if (seen?.length && row?.lab?.last) return reply({ ...row.lab.last, duplicate: true, progress: await summary() });
    const since = new Date(Date.parse(`${jakartaDay(now())}T00:00:00+07:00`)).toISOString();
    const today = await db(`guide_events?${q({ date: `eq.${date}`, type: 'eq.lab', created_at: `gte.${since}`, select: 'id' })}`);
    if ((today?.length ?? 0) >= LAB_PER_DAY) return reply({ error: 'Five lab checks per guide per day. Try again tomorrow.' }, 429);
    const c = await content(fetchFn, now(), date, lang);
    const rubric = c?._lab_rubric;
    if (!Array.isArray(rubric?.must_show) || !rubric.must_show.length) return reply({ error: 'This guide has no lab check' }, 404);
    const prompt = `Lab: ${c['lab.title'] ?? ''}\nSteps: ${[1, 2, 3].map((n) => c[`lab.step_${n}`]).filter(Boolean).join(' / ')}\n`
      + `Checklist items (answer one boolean each, in order):\n${rubric.must_show.map((m, i) => `${i + 1}. ${m}`).join('\n')}\n`
      + `Safety: ${(rubric.safety ?? []).join('; ')}\nPass if: ${rubric.pass_if ?? 'every item is visible'}`;
    const out = await (deps.generate ?? generate)({ key: env.GEMINI_API_KEY, system: LAB_SYSTEM, prompt, images: frames, json: true, timeoutMs: 30000 });
    const verdict = out && parseVerdict(out.text, rubric.must_show.length);
    if (!verdict) return reply({ error: 'The lab check is busy. Your clip is still on your phone; try again.' }, 503);
    const last = { ...verdict, at: new Date(now()).toISOString() };
    let xp = 0;
    const saved = await record('lab', (r) => {
      const next = verdict.verdict === 'approved' ? award(r, 'lab') : r;
      if (next !== r) xp = XP.lab;
      return { ...next, lab: { ...r.lab, checks: (r.lab?.checks ?? 0) + 1, last } };
    });
    if (saved && verdict.verdict === 'teacher') {
      await db('lab_reviews', { method: 'POST', body: JSON.stringify({ owner_id: owner, date, verdict: 'teacher', reason: verdict.reason_en }) });
    }
    return reply({ ...last, xp_awarded: xp, progress: await summary() });
  } catch {
    return reply({ error: 'Guide cloud unavailable. Your progress is kept on this phone.' }, 503);
  }
}
