// Minimal static server for the production build with SPA fallback, used by the e2e tests.
// Service workers need a real HTTP origin, so `ng serve` (no service worker) is not enough.
// `/api/**` is answered by an in-memory mock of the sync backend (see mock-api.mjs).
import { createReadStream, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, normalize, resolve } from 'node:path';
import { handleMockApi } from './mock-api.mjs';

const root = resolve(import.meta.dirname, '../dist/poultry-pal-plus-web/browser');
const port = Number(process.env.PORT ?? 4300);
const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.webmanifest': 'application/manifest+json',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

function resolveFile(urlPath) {
  const file = normalize(join(root, decodeURIComponent(urlPath)));
  if (!file.startsWith(root)) return null;
  try {
    return statSync(file).isFile() ? file : null;
  } catch {
    return null;
  }
}

createServer(async (req, res) => {
  try {
    if (await handleMockApi(req, res)) return;
  } catch (err) {
    console.error(err);
    res.writeHead(500, { 'content-type': 'application/json' });
    res.end('{"success":false,"message":"Mock API error"}');
    return;
  }
  const { pathname } = new URL(req.url ?? '/', 'http://localhost');
  const file = resolveFile(pathname) ?? (extname(pathname) ? null : join(root, 'index.html'));
  if (!file) {
    res.writeHead(404).end();
    return;
  }
  res.writeHead(200, {
    'content-type': types[extname(file)] ?? 'application/octet-stream',
    'cache-control': 'no-cache',
  });
  createReadStream(file).pipe(res);
}).listen(port, () => console.log(`Serving ${root} on http://localhost:${port}`));
