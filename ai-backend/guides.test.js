import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { handleGuides, grade, parseVerdict, streakOf, resetCaches, jakartaDay } from './guides.js';

const env = { SUPABASE_URL: 'https://db.invalid', SUPABASE_SERVICE_ROLE_KEY: 'test', GEMINI_API_KEY: 'k' };
const CONTENT = {
  _answers: { 1: 'b', 2: 'a', 3: 'c' },
  'quiz.1.question': 'Q1?',
  _quiz_explain: { 1: { why: 'Speed is distance over time.', wrong: { a: 'That multiplies.' } } },
  _quiz_pool: [
    { question: 'Pool 0', options: ['w', 'x', 'y', 'z'], answer: 1, explanation: 'Pool zero.' },
    { question: 'Pool 1', options: ['w', 'x', 'y', 'z'], answer: 3, explanation: 'Pool one.' },
    { question: 'Pool 2', options: ['w', 'x', 'y', 'z'], answer: 0 },
  ],
  _lab_rubric: { must_show: ['tray', 'cork', 'timer'], safety: ['no flame'], pass_if: 'all three' },
  'lab.title': 'Measure stream speed',
};
const MANIFEST = { guides: [
  { date: '2026-11-08', revision: 'a'.repeat(64), content: { en: 'issues/2026-11-08/en.json', id: 'issues/2026-11-08/id.json' } },
  { date: '2026-11-06', revision: 'b'.repeat(64), content: { en: 'issues/2026-11-06/en.json', id: 'issues/2026-11-06/id.json' } },
] };
const JPEG = Buffer.from([255, 216, 255, 224, 0, 16, 74, 70]).toString('base64');

/** In-memory stand-in for the few PostgREST calls guides.js makes, plus the Pages files. */
function fakeWorld({ now = Date.parse('2026-11-09T03:00:00Z') } = {}) {
  const tables = { guide_progress: [], guide_events: [], lab_reviews: [] };
  const calls = { pages: 0 };
  const fetch = async (input, options = {}) => {
    const url = new URL(String(input));
    if (url.hostname.endsWith('github.io')) {
      calls.pages++;
      if (url.pathname.endsWith('manifest.json')) return Response.json(MANIFEST);
      if (url.pathname.endsWith('.json')) return Response.json(CONTENT);
      return new Response('', { status: 404 });
    }
    const table = url.pathname.split('/').pop();
    const filters = [...url.searchParams].filter(([k]) => !['select', 'on_conflict'].includes(k));
    const match = (row) => filters.every(([k, v]) => {
      const [opr, val] = [v.slice(0, v.indexOf('.')), v.slice(v.indexOf('.') + 1)];
      return opr === 'eq' ? String(row[k]) === val : opr === 'gte' ? String(row[k]) >= val : true;
    });
    if ((options.method ?? 'GET') === 'GET') return Response.json(tables[table].filter(match));
    const body = JSON.parse(options.body);
    if (table === 'guide_events') {
      if (tables.guide_events.some((e) => e.owner_id === body.owner_id && e.id === body.id)) return Response.json([]);
      const row = { ...body, created_at: new Date(now).toISOString() };
      tables.guide_events.push(row);
      return Response.json([row]);
    }
    if (table === 'guide_progress') {
      const i = tables.guide_progress.findIndex((r) => r.owner_id === body.owner_id && r.date === body.date);
      if (i >= 0) tables.guide_progress[i] = { ...tables.guide_progress[i], ...body };
      else tables.guide_progress.push(body);
      return new Response('');
    }
    tables[table].push(body);
    return new Response('');
  };
  return { tables, calls, fetch, now: () => now };
}

const users = { 'tok-A': { sub: 'A' }, 'tok-B': { sub: 'B' }, 'tok-G': { sub: 'G', firebase: { sign_in_provider: 'anonymous' } } };
const verify = async (t) => users[t] ?? null;
const call = (world, body, { token = 'tok-A', generate } = {}) => handleGuides(
  new Request('https://x.invalid', { method: 'POST', headers: token ? { authorization: `Bearer ${token}` } : {}, body: JSON.stringify(body) }),
  env, { verify, fetch: world.fetch, now: world.now, generate });

beforeEach(() => resetCaches());

test('a token is required and nothing is read without one', async () => {
  const world = fakeWorld();
  for (const token of [null, 'bad']) {
    const res = await call(world, { op: 'progress' }, { token });
    assert.equal(res.status, 401);
  }
  assert.equal(world.calls.pages, 0);
});

test('a story event awards its stop XP once, even when resent or sent with a new id', async () => {
  const world = fakeWorld();
  const first = await (await call(world, { op: 'event', id: 'evt-00001', date: '2026-11-08', type: 'story_read' })).json();
  assert.equal(first.progress.total_xp, 10);
  const again = await (await call(world, { op: 'event', id: 'evt-00001', date: '2026-11-08', type: 'story_read' })).json();
  assert.equal(again.duplicate, true);
  const other = await (await call(world, { op: 'event', id: 'evt-00002', date: '2026-11-08', type: 'story_read' })).json();
  assert.equal(other.progress.total_xp, 10);
  const physics = await (await call(world, { op: 'event', id: 'evt-00003', date: '2026-11-08', type: 'physics_read' })).json();
  assert.equal(physics.progress.issues['2026-11-08'].xp, 30);
  assert.equal((await call(world, { op: 'event', id: 'evt-00004', date: '2026-11-08', type: 'lab_approved' })).status, 400);
});

test('quiz is graded from the published JSON with explanations; XP only on the first pass', async () => {
  const world = fakeWorld();
  const fail = await (await call(world, { op: 'quiz', id: 'quiz-0001', date: '2026-11-08', lang: 'en',
    answers: [{ qid: 'p1', choice: 'a' }, { qid: 'p2', choice: 'b' }, { qid: 'p3', choice: 'c' }] })).json();
  assert.equal(fail.score, 1);
  assert.equal(fail.xp_awarded, 0);
  assert.deepEqual(fail.results[0], { qid: 'p1', correct: false, answer: 'b', explanation: 'Speed is distance over time.', wrong: 'That multiplies.' });
  const pass = await (await call(world, { op: 'quiz', id: 'quiz-0002', date: '2026-11-08', lang: 'en',
    answers: [{ qid: 'pool-0', choice: 'b' }, { qid: 'pool-1', choice: 'd' }, { qid: 'pool-2', choice: 'b' }] })).json();
  assert.equal(pass.passed, true);
  assert.equal(pass.xp_awarded, 10);
  assert.equal(pass.results[2].explanation, null); // never invented
  const again = await (await call(world, { op: 'quiz', id: 'quiz-0003', date: '2026-11-08', lang: 'en',
    answers: [{ qid: 'p1', choice: 'b' }, { qid: 'p2', choice: 'a' }, { qid: 'p3', choice: 'c' }] })).json();
  assert.equal(again.score, 3);
  assert.equal(again.xp_awarded, 0);
  assert.equal(again.progress.total_xp, 10);
  // The first attempt keeps the picked option so the Insights dashboard can show the A-D split.
  assert.deepEqual(world.tables.guide_progress[0].quiz.first.answers.map((a) => a.choice), ['a', 'b', 'c']);
  assert.equal(world.calls.pages, 2, 'manifest and content are cached by revision');
  const bad = await call(world, { op: 'quiz', id: 'quiz-0004', date: '2026-11-08', answers: [{ qid: 'pool-9', choice: 'a' }, { qid: 'p1', choice: 'a' }, { qid: 'p2', choice: 'a' }] });
  assert.equal(bad.status, 400);
});

test('grade falls back to the matching pool explanation for a printed question', () => {
  const c = { _answers: { 1: 'a' }, 'quiz.1.question': 'Same?', _quiz_pool: [{ question: 'Same?', answer: 0, explanation: 'From pool.' }] };
  assert.equal(grade(c, [{ qid: 'p1', choice: 'a' }])[0].explanation, 'From pool.');
});

test('lab verdicts are parsed strictly and approval needs every item', () => {
  const ok = '{"verdict":"approved","reason_en":"Good","reason_id":"Bagus","checklist":[true,true,true]}';
  assert.equal(parseVerdict(ok, 3).verdict, 'approved');
  assert.equal(parseVerdict('```json\n' + ok + '\n```', 3).verdict, 'approved');
  assert.equal(parseVerdict(ok.replace('true]', 'false]'), 3).verdict, 'retry');
  assert.equal(parseVerdict(ok, 2), null);
  assert.equal(parseVerdict(ok.replace('approved', 'yes'), 3), null);
  assert.equal(parseVerdict('{"verdict":"retry","reason_en":"x","checklist":[true,true,true]}', 3), null);
  assert.equal(parseVerdict('not json', 3), null);
});

test('lab: rubric comes from the published JSON, approval awards 20 XP once, frames are never stored', async () => {
  const world = fakeWorld();
  let prompt;
  const generate = async (req) => { prompt = req; return { text: '{"verdict":"approved","reason_en":"All there","reason_id":"Lengkap","checklist":[true,true,true]}' }; };
  const body = { op: 'lab', id: 'lab-00001', date: '2026-11-08', lang: 'en', frames: [JPEG, JPEG], _lab_rubric: { must_show: ['nothing'] } };
  const first = await (await call(world, body, { generate })).json();
  assert.equal(first.verdict, 'approved');
  assert.equal(first.xp_awarded, 20);
  assert.match(prompt.prompt, /1\. tray\n2\. cork\n3\. timer/);
  assert.doesNotMatch(prompt.prompt, /nothing/);
  assert.equal(prompt.images.length, 2);
  const repeat = await (await call(world, body, { generate: () => assert.fail('no second model call') })).json();
  assert.equal(repeat.duplicate, true);
  const second = await (await call(world, { ...body, id: 'lab-00002' }, { generate })).json();
  assert.equal(second.xp_awarded, 0);
  assert.equal(second.progress.total_xp, 20);
  assert.doesNotMatch(JSON.stringify(world.tables), new RegExp(JPEG.slice(0, 6).replace(/[+/]/g, '\\$&')));
});

test('lab: teacher verdict is queued for review; invalid model output is a 503, not a verdict', async () => {
  const world = fakeWorld();
  const teacher = async () => ({ text: '{"verdict":"teacher","reason_en":"Unclear","reason_id":"Tidak jelas","checklist":[false,false,false]}' });
  await call(world, { op: 'lab', id: 'lab-00003', date: '2026-11-08', frames: [JPEG] }, { generate: teacher });
  assert.equal(world.tables.lab_reviews.length, 1);
  assert.equal(world.tables.lab_reviews[0].owner_id, 'A');
  const broken = await call(world, { op: 'lab', id: 'lab-00004', date: '2026-11-08', frames: [JPEG] }, { generate: async () => ({ text: '{"verdict":"maybe"}' }) });
  assert.equal(broken.status, 503);
});

test('lab: size and rate limits', async () => {
  const world = fakeWorld();
  const big = await call(world, { op: 'lab', id: 'lab-00005', date: '2026-11-08', frames: ['A'.repeat(2.2e6)] });
  assert.equal(big.status, 413);
  assert.equal((await call(world, { op: 'lab', id: 'lab-00006', date: '2026-11-08', frames: Array(9).fill(JPEG) })).status, 400);
  assert.equal((await call(world, { op: 'lab', id: 'lab-00007', date: '2026-11-08', frames: ['iVBORw0K'] })).status, 400);
  const retry = async () => ({ text: '{"verdict":"retry","reason_en":"Show the timer","reason_id":"Tunjukkan timer","checklist":[true,true,false]}' });
  for (let i = 0; i < 5; i++) {
    assert.equal((await call(world, { op: 'lab', id: `lab-1000${i}`, date: '2026-11-08', frames: [JPEG] }, { generate: retry })).status, 200);
  }
  assert.equal((await call(world, { op: 'lab', id: 'lab-20000', date: '2026-11-08', frames: [JPEG] }, { generate: retry })).status, 429);
  assert.equal((await call(world, { op: 'lab', id: 'lab-20001', date: '2026-11-08', frames: [JPEG] }, { generate: retry, token: 'tok-B' })).status, 200);
});

test('streak: a day without a published issue does not break it; days are Asia/Jakarta', () => {
  const at = (iso) => ({ stops: { story: iso } });
  // Read on 6 Nov and 8 Nov (Jakarta); 7 Nov had no issue. Today 9 Nov, not read yet.
  const rows = [at('2026-11-06T02:00:00Z'), at('2026-11-08T02:00:00Z')];
  assert.equal(streakOf(rows, ['2026-11-06', '2026-11-08'], '2026-11-09').streak, 2);
  // If 7 Nov had an issue that was missed, the streak restarts.
  assert.equal(streakOf(rows, ['2026-11-06', '2026-11-07', '2026-11-08'], '2026-11-09').streak, 1);
  // 23:30 WIB on 8 Nov is 16:30 UTC; 00:30 WIB on 9 Nov is still 8 Nov in UTC.
  assert.equal(jakartaDay(Date.parse('2026-11-08T16:30:00Z')), '2026-11-08');
  assert.equal(jakartaDay(Date.parse('2026-11-08T17:30:00Z')), '2026-11-09');
  const midnight = streakOf([at('2026-11-08T16:30:00Z'), at('2026-11-08T17:30:00Z')], ['2026-11-08', '2026-11-09'], '2026-11-09');
  assert.equal(midnight.streak, 2);
  assert.equal(midnight.best_streak, 2);
  const week = streakOf(rows, ['2026-11-03', '2026-11-06', '2026-11-08'], '2026-11-09').week;
  assert.deepEqual(week.map((d) => d.status), ['today', 'future', 'future', 'future', 'future', 'future', 'future']);
  const lastWeek = streakOf(rows, ['2026-11-03', '2026-11-06', '2026-11-08'], '2026-11-08').week;
  assert.deepEqual(lastWeek.map((d) => d.status), ['off', 'missed', 'off', 'off', 'read', 'off', 'read']);
});

test('import needs the server-signed guest claim and keeps earliest stop times', async () => {
  const world = fakeWorld();
  const guest = await (await call(world, { op: 'event', id: 'evt-guest1', date: '2026-11-08', type: 'story_read' }, { token: 'tok-G' })).json();
  assert.match(guest.progress.guest_claim, /^[a-f0-9]{64}$/);
  const mine = await (await call(world, { op: 'progress' })).json();
  assert.equal(mine.guest_claim, undefined, 'only guests get a claim');
  assert.equal((await call(world, { op: 'import', guest_uid: 'G', guest_claim: 'f'.repeat(64) })).status, 400);
  assert.equal((await call(world, { op: 'import', guest_uid: 'B', guest_claim: guest.progress.guest_claim })).status, 400);
  const res = await (await call(world, { op: 'import', guest_uid: 'G', guest_claim: guest.progress.guest_claim })).json();
  assert.equal(res.progress.total_xp, 10);
  const again = await (await call(world, { op: 'import', guest_uid: 'G', guest_claim: guest.progress.guest_claim })).json();
  assert.equal(again.progress.total_xp, 10);
});
