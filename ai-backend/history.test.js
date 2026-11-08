import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handleHistory } from './history.js';
const env = { SUPABASE_URL: 'https://example.invalid', SUPABASE_SERVICE_ROLE_KEY: 'test' };
const request = body => new Request('https://example.invalid', { method: 'POST', headers: { authorization: 'Bearer test' }, body: JSON.stringify(body) });
test('unauthenticated history never reaches storage', async () => {
 const result = await handleHistory(request({op:'list'}), env, {verify:async()=>null, fetch:()=>{throw Error('must not fetch');}});
 assert.equal(result.status,401);
});
test('caller cannot select another owner', async () => {
 let url;
 const result = await handleHistory(request({op:'list',owner_id:'victim'}), env, {
  verify:async()=>({sub:'owner-A'}), fetch:async input=>{url=String(input);return new Response('[]');},
 });
 assert.equal(result.status,200);
 assert.equal(new URL(url).searchParams.get('owner_id'),'eq.owner-A');
});
test('invalid record and traversal photo IDs are rejected before storage',async()=>{
 for (const body of [{op:'save',id:'scan-1',data:{}},{op:'photo',id:'../victim'}]) {
  const result=await handleHistory(request(body),env,{verify:async()=>({sub:'A'}),fetch:()=>{throw Error('must not fetch');}});
  assert.equal(result.status,400);
 }
});
test('incremental cursor is owner-scoped and rejects query syntax injection',async()=>{
 let url;
 const deps={verify:async()=>({sub:'A'}),fetch:async input=>{url=String(input);return new Response('[]');}};
 const result=await handleHistory(request({op:'list',cursor:{time:'2026-11-08T10:00:00.000+00:00',id:'scan-1'}}),env,deps);
 assert.equal(result.status,200);
 const q=new URL(url).searchParams;
 assert.equal(q.get('owner_id'),'eq.A');
 assert.equal(q.get('order'),'updated_at.asc,id.asc');
 assert.match(q.get('or'),/id.gt.scan-1/);
 const bad=await handleHistory(request({op:'list',cursor:{time:'now),owner_id.neq.A',id:'scan-1'}}),env,deps);
 assert.equal(bad.status,400);
});
