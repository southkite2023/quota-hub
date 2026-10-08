import { validateSnapshot } from '../../../packages/contracts/src/index.mjs';

const currencies = new Set(['CNY', 'USD']);
const money = value => typeof value === 'string' && /^(0|[1-9]\d*)(\.\d+)?$/.test(value);
const fields = [
  ['available', 'total_balance'],
  ['bonus', 'granted_balance'],
  ['cash', 'topped_up_balance'],
];

function account(currency, info, at) {
  return {
    id: `deepseek_${currency.toLowerCase()}`, provider: 'deepseek', label: `DeepSeek API · ${currency}`,
    lastSuccessAt: at,
    metrics: fields.map(([key, source]) => ({key, kind: 'money', state: 'ok', value: info[source], unit: currency})),
  };
}

export function parseBalance(body, at) {
  if (!body || !Array.isArray(body.balance_infos) || !body.balance_infos.length || typeof body.is_available !== 'boolean') throw Error('provider_unavailable');
  const seen = new Set();
  const accounts = body.balance_infos.map(info => {
    if (!info || !currencies.has(info.currency) || seen.has(info.currency) ||
        fields.some(([, source]) => !money(info[source]))) throw Error('provider_unavailable');
    seen.add(info.currency);
    return account(info.currency, info, at);
  });
  const snapshot = {schemaVersion: 1, generatedAt: at, accounts};
  if (validateSnapshot(snapshot).length) throw Error('provider_unavailable');
  return snapshot;
}

export function failureSnapshot(previous, code, at) {
  const source = previous?.accounts ?? [{
    id: 'deepseek_cny', provider: 'deepseek', label: 'DeepSeek API · CNY', lastSuccessAt: null,
    metrics: fields.map(([key]) => ({key, kind: 'money', unit: 'CNY', state: 'error', value: null, errorCode: code})),
  }];
  const accounts = source.map(account => ({
    ...account,
    metrics: account.metrics.map(metric => ({...metric, state: account.lastSuccessAt ? 'stale' : 'error', value: account.lastSuccessAt ? metric.value : null, errorCode: code})),
  }));
  return {schemaVersion: 1, generatedAt: at, accounts};
}

export function createCollector({apiKey, fetchImpl = fetch, now = () => new Date(), ttlMs = 300000}) {
  let lastSuccess = null;
  let latest = null;
  let fetchedAt = 0;
  let pending = null;
  async function update() {
    const at = now().toISOString();
    try {
      const response = await fetchImpl('https://api.deepseek.com/user/balance', {
        headers: {Accept: 'application/json', Authorization: `Bearer ${apiKey}`},
        signal: AbortSignal.timeout(8000),
      });
      if (!response.ok) throw Error(response.status === 401 || response.status === 403 ? 'unauthorized' : response.status === 429 ? 'rate_limited' : 'provider_unavailable');
      const body = await response.json();
      latest = parseBalance(body, at);
      lastSuccess = latest;
    } catch (error) {
      const code = error.message === 'unauthorized' || error.message === 'rate_limited' ? error.message
        : error.name === 'TimeoutError' || error.name === 'AbortError' ? 'timeout' : 'provider_unavailable';
      latest = failureSnapshot(lastSuccess, code, at);
    }
    fetchedAt = now().getTime();
    return latest;
  }
  return async () => {
    if (latest && now().getTime() - fetchedAt < ttlMs) return latest;
    pending ??= update().finally(() => { pending = null; });
    return pending;
  };
}
