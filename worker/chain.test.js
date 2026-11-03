import test from 'node:test';
import assert from 'node:assert';
import { CHAIN, generate, nextPacificMidnight, restUntil } from './chain.js';

const ok = (text) => ({ status: 200, text: async () => JSON.stringify({ candidates: [{ content: { parts: [{ text }] } }] }) });
const fail = (status, body = '{}') => ({ status, text: async () => body });

/** fetch that answers each model from a queue of replies, recording the order called. */
function fakeFetch(replies) {
  const calls = [];
  const fetch = async (url) => {
    const model = /models\/(.+):generateContent/.exec(url)[1];
    calls.push(model);
    const r = replies[model]?.shift();
    if (r instanceof Error) throw r;
    return r ?? fail(500);
  };
  return { fetch, calls };
}

const run = (replies, opts = {}) => {
  const f = fakeFetch(replies);
  return generate({ key: 'k', prompt: 'p', json: opts.json ?? true }, { fetch: f.fetch, now: opts.now ?? (() => 1e12), log: () => {} })
    .then((out) => ({ out, calls: f.calls }));
};

test.beforeEach(() => restUntil.clear());

test('primary answers', async () => {
  const { out, calls } = await run({ [CHAIN[0]]: [ok('{"a":1}')] });
  assert.equal(out.model, CHAIN[0]);
  assert.deepEqual(calls, [CHAIN[0]]);
});

test('429 per minute rests the model for retryDelay, then it is used again', async () => {
  const body = '{"error":{"details":[{"retryDelay":"30s"}]}}';
  let t = 1e12;
  const first = await run({ [CHAIN[0]]: [fail(429, body)], [CHAIN[1]]: [ok('{}')] }, { now: () => t });
  assert.equal(first.out.model, CHAIN[1]);
  t += 10000;
  assert.deepEqual((await run({ [CHAIN[1]]: [ok('{}')] }, { now: () => t })).calls, [CHAIN[1]]);
  t += 21000;
  assert.equal((await run({ [CHAIN[0]]: [ok('{}')] }, { now: () => t })).out.model, CHAIN[0]);
});

test('429 daily cap rests the model until Pacific midnight', async () => {
  const now = Date.UTC(2026, 10, 3, 3, 0); // 3 Nov 19:00 PST
  await run({ [CHAIN[0]]: [fail(429, 'GenerateRequestsPerDayPerProjectPerModel')], [CHAIN[1]]: [ok('{}')] }, { now: () => now });
  assert.equal(restUntil.get(CHAIN[0]), Date.UTC(2026, 10, 3, 8, 0)); // 4 Nov 00:00 PST = 08:00 UTC
  assert.equal(nextPacificMidnight(now), Date.UTC(2026, 10, 3, 8, 0));
});

test('5xx and timeout go to the next model at once and rest 60 s', async () => {
  const { out, calls } = await run({
    [CHAIN[0]]: [fail(503)],
    [CHAIN[1]]: [new Error('TimeoutError')],
    [CHAIN[2]]: [ok('{}')],
  });
  assert.equal(out.model, CHAIN[2]);
  assert.deepEqual(calls, CHAIN.slice(0, 3));
  assert.equal(restUntil.get(CHAIN[0]), 1e12 + 60000);
  assert.equal(restUntil.get(CHAIN[1]), 1e12 + 60000);
});

test('404 drops the model', async () => {
  await run({ [CHAIN[0]]: [fail(404)], [CHAIN[1]]: [ok('{}')] });
  assert.equal(restUntil.get(CHAIN[0]), Infinity);
});

test('invalid JSON retries once on the same model, then moves on', async () => {
  const once = await run({ [CHAIN[0]]: [ok('not json'), ok('{"a":1}')] });
  assert.deepEqual(once.calls, [CHAIN[0], CHAIN[0]]);
  assert.equal(once.out.model, CHAIN[0]);
  const twice = await run({ [CHAIN[0]]: [ok('x'), ok('y')], [CHAIN[1]]: [ok('{}')] });
  assert.deepEqual(twice.calls, [CHAIN[0], CHAIN[0], CHAIN[1]]);
});

test('plain text is accepted when JSON is not asked for', async () => {
  assert.equal((await run({ [CHAIN[0]]: [ok('Halo')] }, { json: false })).out.text, 'Halo');
});

test('null when every model fails (the app falls back to the bank)', async () => {
  const { out, calls } = await run({});
  assert.equal(out, null);
  assert.deepEqual(calls, CHAIN);
});
