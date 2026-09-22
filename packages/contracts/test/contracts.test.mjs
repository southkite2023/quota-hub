import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { validateSnapshot } from '../src/index.mjs';

const cases = JSON.parse(readFileSync(new URL('../fixtures/cases.json', import.meta.url), 'utf8'));
for (const { name, ...snapshot } of cases) {
  test(`fixture: ${name}`, () => assert.deepEqual(validateSnapshot(snapshot), []));
}
const clone = name => structuredClone(cases.find(item => item.name === name));
test('zero is a known balance', () => {
  const { name, ...snapshot } = clone('zero');
  assert.equal(snapshot.accounts[0].metrics[0].value, '0');
  assert.deepEqual(validateSnapshot(snapshot), []);
});
test('unknown cannot masquerade as zero', () => {
  const { name, ...snapshot } = clone('unknown');
  snapshot.accounts[0].metrics[1].value = '0';
  assert.match(validateSnapshot(snapshot).join(' '), /value must be null/);
});
test('stale value needs previous success', () => {
  const { name, ...snapshot } = clone('stale');
  snapshot.accounts[0].lastSuccessAt = null;
  assert.match(validateSnapshot(snapshot).join(' '), /requires lastSuccessAt/);
});
test('first error cannot carry stale value', () => {
  const { name, ...snapshot } = clone('first_failure');
  snapshot.accounts[0].metrics[0].value = '8.20';
  assert.match(validateSnapshot(snapshot).join(' '), /value must be null/);
});
test('duplicate account and metric keys are rejected', () => {
  const { name, ...snapshot } = clone('normal');
  snapshot.accounts.push(structuredClone(snapshot.accounts[0]));
  snapshot.accounts[0].metrics.push(structuredClone(snapshot.accounts[0].metrics[0]));
  assert.match(validateSnapshot(snapshot).join(' '), /duplicate/);
});
test('secrets and arbitrary payload fields are rejected', () => {
  const { name, ...snapshot } = clone('zero');
  snapshot.accounts[0].apiKey = 'secret';
  assert.match(validateSnapshot(snapshot).join(' '), /apiKey unexpected/);
});
