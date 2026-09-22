const states = new Set(['ok', 'unknown', 'stale', 'error']);
const kinds = new Set(['money', 'traffic', 'expiry']);
const errors = new Set(['timeout', 'unauthorized', 'rate_limited', 'provider_unavailable', 'stale_cache']);
const iso = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/;
const own = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
const validDate = value => typeof value === 'string' && iso.test(value) && !Number.isNaN(Date.parse(value));
const record = value => value !== null && typeof value === 'object' && !Array.isArray(value);

/** Return all structural and semantic errors. Never include input values in errors. */
export function validateSnapshot(snapshot) {
  const issues = [];
  if (!record(snapshot)) return ['snapshot must be an object'];
  if (snapshot.schemaVersion !== 1) issues.push('schemaVersion must be 1');
  if (!validDate(snapshot.generatedAt)) issues.push('generatedAt must be an ISO timestamp with timezone');
  if (!Array.isArray(snapshot.accounts)) return [...issues, 'accounts must be an array'];
  const accountIds = new Set();
  snapshot.accounts.forEach((account, ai) => {
    const at = `accounts[${ai}]`;
    if (!record(account)) { issues.push(`${at} must be an object`); return; }
    if (typeof account.id !== 'string' || !/^[a-z0-9][a-z0-9_-]*$/.test(account.id)) issues.push(`${at}.id invalid`);
    else if (accountIds.has(account.id)) issues.push(`${at}.id duplicate`);
    else accountIds.add(account.id);
    for (const key of ['provider', 'label']) if (typeof account[key] !== 'string' || !account[key].trim()) issues.push(`${at}.${key} required`);
    if (account.lastSuccessAt !== null && !validDate(account.lastSuccessAt)) issues.push(`${at}.lastSuccessAt invalid`);
    if (!own(account, 'lastSuccessAt')) issues.push(`${at}.lastSuccessAt required`);
    if (!Array.isArray(account.metrics) || account.metrics.length === 0) { issues.push(`${at}.metrics must be nonempty`); return; }
    const keys = new Set();
    account.metrics.forEach((metric, mi) => {
      const mt = `${at}.metrics[${mi}]`;
      if (!record(metric)) { issues.push(`${mt} must be an object`); return; }
      if (typeof metric.key !== 'string' || !/^[a-z][a-z0-9_]*$/.test(metric.key)) issues.push(`${mt}.key invalid`);
      else if (keys.has(metric.key)) issues.push(`${mt}.key duplicate`);
      else keys.add(metric.key);
      if (!kinds.has(metric.kind)) issues.push(`${mt}.kind invalid`);
      if (!states.has(metric.state)) issues.push(`${mt}.state invalid`);
      if (metric.state === 'ok' || metric.state === 'stale') {
        if (typeof metric.value !== 'string') issues.push(`${mt}.value must be a string`);
        if (account.lastSuccessAt === null || !validDate(account.lastSuccessAt)) issues.push(`${mt} requires lastSuccessAt`);
      } else if (metric.state === 'unknown' || metric.state === 'error') {
        if (metric.value !== null) issues.push(`${mt}.value must be null`);
      }
      if (metric.kind === 'money' && (!/^[A-Z]{3}$/.test(metric.unit ?? '') || (typeof metric.value === 'string' && !/^(?:0|[1-9]\d*)(?:\.\d+)?$/.test(metric.value)))) issues.push(`${mt} invalid money value/unit`);
      if (metric.kind === 'traffic' && (metric.unit !== 'byte' || (typeof metric.value === 'string' && !/^(?:0|[1-9]\d*)$/.test(metric.value)))) issues.push(`${mt} invalid traffic value/unit`);
      if (metric.kind === 'expiry' && (metric.unit !== 'datetime' || (typeof metric.value === 'string' && !validDate(metric.value)))) issues.push(`${mt} invalid expiry value/unit`);
      if (own(metric, 'errorCode') && !errors.has(metric.errorCode)) issues.push(`${mt}.errorCode invalid`);
      if (metric.state === 'error' && !own(metric, 'errorCode')) issues.push(`${mt}.errorCode required`);
      if (metric.state === 'stale' && !own(metric, 'errorCode')) issues.push(`${mt}.errorCode required`);
      if (['ok', 'unknown'].includes(metric.state) && own(metric, 'errorCode')) issues.push(`${mt}.errorCode unexpected`);
    });
  });
  return issues;
}
