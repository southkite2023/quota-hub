import assert from 'node:assert/strict';
import test from 'node:test';
import {parseBalance, failureSnapshot, createCollector} from '../src/deepseek.mjs';
import {validateSnapshot} from '../../../packages/contracts/src/index.mjs';

const at = '2026-09-22T12:00:00.000Z';
const body = {is_available: false, balance_infos: [{currency: 'CNY', total_balance: '0', granted_balance: '0', topped_up_balance: '0'}]};

test('zero is a known balance and passes the shared contract', () => {
  const snapshot = parseBalance(body, at);
  assert.deepEqual(validateSnapshot(snapshot), []);
  assert.equal(snapshot.accounts[0].metrics[0].value, '0');
  assert.equal(snapshot.accounts[0].metrics[0].state, 'ok');
});

test('distinct currencies remain in separate accounts', () => {
  const snapshot = parseBalance({...body, balance_infos: [...body.balance_infos, {...body.balance_infos[0], currency: 'USD'}]}, at);
  assert.deepEqual(snapshot.accounts.map(item => item.id), ['deepseek_cny', 'deepseek_usd']);
  assert.deepEqual(validateSnapshot(snapshot), []);
});

test('malformed response does not become a false zero', () => {
  assert.throws(() => parseBalance({is_available: true, balance_infos: [{currency: 'CNY', total_balance: '0'}]}, at));
  const failure = failureSnapshot(null, 'provider_unavailable', at);
  assert.deepEqual(validateSnapshot(failure), []);
  assert.equal(failure.accounts[0].metrics[0].value, null);
});

test('refresh failure marks last known values stale and never echoes credentials', async () => {
  let calls = 0;
  const collect = createCollector({apiKey: 'secret', ttlMs: 0, fetchImpl: async () => {
    calls++;
    if (calls === 1) return {ok: true, json: async () => body};
    throw new Error('sensitive upstream text');
  }});
  await collect();
  const stale = await collect();
  assert.deepEqual(validateSnapshot(stale), []);
  assert.equal(stale.accounts[0].metrics[0].state, 'stale');
  assert.equal(stale.accounts[0].metrics[0].value, '0');
  assert.ok(!JSON.stringify(stale).includes('sensitive'));
});

test('401 is authorization failure without a cached balance', async () => {
  const collect = createCollector({apiKey: 'secret', fetchImpl: async () => ({ok: false, status: 401})});
  const snapshot = await collect();
  assert.equal(snapshot.accounts[0].metrics[0].errorCode, 'unauthorized');
  assert.deepEqual(validateSnapshot(snapshot), []);
});
