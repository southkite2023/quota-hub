import { validateSnapshot } from '../../packages/contracts/src/index.mjs';
import cases from '../../packages/contracts/fixtures/cases.json' with { type: 'json' };

const byName = Object.fromEntries(cases.map(({ name, ...snapshot }) => [name, snapshot]));
const scenarios = [
  ['overview', '综合预览'], ['zero', '零余额'], ['unknown', '未知'],
  ['stale', '过期缓存'], ['first_failure', '首次失败'],
];
const providers = {
  deepseek: { name: 'DeepSeek API', icon: '✳', subtitle: 'API 账户余额' },
  subscription: { name: '代理订阅', icon: '◎', subtitle: '可用订阅流量' },
  aliyun: { name: '阿里云', icon: '▲', subtitle: '云账户现金余额' },
};
const metricNames = { available: '可用余额', bonus: '赠送余额', remaining: '剩余流量', expires_at: '到期时间', cash: '现金余额' };
const stateNames = { ok: '数据正常', unknown: '数据未知', stale: '缓存已过期', error: '查询失败' };
const errorNames = { timeout: '连接超时', unauthorized: '授权失败', rate_limited: '请求过频', provider_unavailable: '服务不可用', stale_cache: '缓存过期' };
const $ = selector => document.querySelector(selector);
let active = 'overview';
let privateMode = false;

function makeSnapshot(name) {
  const snapshot = structuredClone(byName.normal);
  snapshot.accounts.push(structuredClone(byName.zero.accounts[0]));
  if (name === 'unknown') snapshot.accounts[1] = structuredClone(byName.unknown.accounts[0]);
  if (name === 'stale') snapshot.accounts[0] = structuredClone(byName.stale.accounts[0]);
  if (name === 'first_failure') snapshot.accounts[2] = structuredClone(byName.first_failure.accounts[0]);
  return snapshot;
}

function format(metric) {
  if (metric.state === 'unknown') return { value: '未知', unit: '', caption: '供应商未提供这项数据', muted: true };
  if (metric.state === 'error') return { value: '暂不可用', unit: '', caption: errorNames[metric.errorCode] ?? '查询失败', muted: true };
  if (metric.kind === 'money') return { value: privateMode ? '••••' : Number(metric.value).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), unit: metric.unit === 'CNY' ? 'CNY' : metric.unit, caption: metric.state === 'stale' ? `上次成功值 · ${errorNames[metric.errorCode]}` : '余额以原币种展示' };
  if (metric.kind === 'traffic') {
    const gib = Number(metric.value) / 1073741824;
    return { value: gib.toLocaleString('zh-CN', { maximumFractionDigits: 2 }), unit: 'GiB', caption: '1 GiB = 1,073,741,824 字节' };
  }
  return { value: new Intl.DateTimeFormat('zh-CN', { year: 'numeric', month: '2-digit', day: '2-digit', timeZone: 'Asia/Shanghai' }).format(new Date(metric.value)), unit: '', caption: '北京时间' };
}

function el(tag, className, value) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (value != null) node.textContent = value;
  return node;
}
function append(parent, ...children) { parent.append(...children); return parent; }

function renderCard(account, index) {
  const config = providers[account.provider] ?? { name: account.provider, icon: '◈', subtitle: '账户指标' };
  const card = el('article', `card ${account.provider}`);
  const inner = append(card, el('div', 'card-inner'));
  const top = append(inner, el('div', 'card-top'));
  append(top, el('span', 'provider-icon', config.icon), el('span', 'card-index', `SERVICE / 0${index + 1}`));
  append(inner, el('div', 'card-provider', config.subtitle.toUpperCase()), el('h3', '', config.name));
  const [primary, ...rest] = account.metrics;
  const display = format(primary);
  append(inner, el('div', 'metric-label', metricNames[primary.key] ?? primary.key));
  const value = append(inner, el('div', `metric-value${display.muted ? ' muted' : ''}`));
  append(value, el('span', privateMode && primary.kind === 'money' && primary.value !== null ? 'privacy-mask' : '', display.value), el('span', 'unit', display.unit));
  append(inner, el('div', 'metric-caption', display.caption));
  for (const metric of rest) {
    const secondary = append(inner, el('div', 'metric-secondary'));
    append(secondary, el('span', 'metric-label', metricNames[metric.key] ?? metric.key));
    const second = format(metric);
    append(secondary, el('span', 'secondary-value', second.value + (second.unit ? ` ${second.unit}` : '')));
  }
  const status = primary.state === 'error' ? 'error' : primary.state === 'stale' ? 'warning' : primary.state === 'unknown' ? 'unknown' : '';
  const bottom = append(card, el('div', 'card-bottom'));
  append(bottom, el('span', `state-pill ${status}`, `● ${stateNames[primary.state]}`));
  const time = el('time', '', account.lastSuccessAt ? `上次成功 ${new Intl.DateTimeFormat('zh-CN', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Shanghai' }).format(new Date(account.lastSuccessAt))}` : '尚无成功记录');
  if (account.lastSuccessAt) time.dateTime = account.lastSuccessAt;
  append(bottom, time);
  return card;
}

function render() {
  const snapshot = makeSnapshot(active);
  const issues = validateSnapshot(snapshot);
  if (issues.length) { $('#cards').replaceChildren(el('p', '', '演示数据未通过协议校验。')); return; }
  $('#scenario-options').replaceChildren(...scenarios.map(([key, label]) => {
    const button = el('button', '', label);
    button.type = 'button';
    button.setAttribute('aria-pressed', String(key === active));
    button.addEventListener('click', () => { active = key; render(); });
    return button;
  }));
  $('#cards').replaceChildren(...snapshot.accounts.map(renderCard));
  $('#account-count').firstChild.textContent = String(snapshot.accounts.length).padStart(2, '0');
  $('#account-heading-count').textContent = String(snapshot.accounts.length).padStart(2, '0');
  const known = snapshot.accounts.flatMap(account => account.metrics).filter(metric => ['ok', 'stale'].includes(metric.state)).length;
  $('#known-count').firstChild.textContent = String(known).padStart(2, '0');
  $('#snapshot-time').textContent = `模拟快照 ${new Intl.DateTimeFormat('zh-CN', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Shanghai' }).format(new Date(snapshot.generatedAt))} · 北京时间`;
}

$('#privacy').addEventListener('click', event => {
  privateMode = !privateMode;
  event.currentTarget.setAttribute('aria-pressed', String(privateMode));
  event.currentTarget.querySelector('span:last-child').textContent = privateMode ? '显示金额' : '隐藏金额';
  render();
});
$('#refresh').addEventListener('click', () => { active = 'overview'; render(); });
render();
