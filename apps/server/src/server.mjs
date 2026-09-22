import { createServer } from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { createCollector } from './deepseek.mjs';

const apiKey = process.env.DEEPSEEK_API_KEY;
const accessToken = process.env.QUOTA_HUB_READ_TOKEN;
if (!apiKey || !accessToken || accessToken.length < 32 || accessToken === apiKey) {
  console.error('Set DEEPSEEK_API_KEY and a distinct QUOTA_HUB_READ_TOKEN (at least 32 characters).');
  process.exit(1);
}
const collect = createCollector({apiKey});
const host = process.env.QUOTA_HUB_HOST || '127.0.0.1';
const port = Number(process.env.QUOTA_HUB_PORT || 8787);
const authorize = value => {
  const expected = Buffer.from(`Bearer ${accessToken}`);
  const received = Buffer.from(value || '');
  return received.length === expected.length && timingSafeEqual(received, expected);
};
createServer(async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  if (req.url !== '/api/v1/snapshot' || req.method !== 'GET') {
    res.writeHead(404).end('{"error":"not_found"}');
  } else if (!authorize(req.headers.authorization)) {
    res.writeHead(401).end('{"error":"unauthorized"}');
  } else {
    const snapshot = await collect();
    res.writeHead(200).end(JSON.stringify(snapshot));
  }
}).listen(port, host, () => console.log(`Quota Hub listening on ${host}:${port}`));
