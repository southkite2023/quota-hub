import { readFileSync, writeFileSync } from 'node:fs';

const source = new URL('../packages/contracts/fixtures/cases.json', import.meta.url);
const target = new URL('../apps/client/assets/cases.json', import.meta.url);
const expected = readFileSync(source);
if (process.argv.includes('--check')) {
  const actual = readFileSync(target);
  if (!expected.equals(actual)) {
    console.error('Flutter demo asset differs from contract fixtures. Run node scripts/sync-client-fixtures.mjs.');
    process.exitCode = 1;
  }
} else {
  writeFileSync(target, expected);
  console.log('Updated Flutter demo fixture asset.');
}
