const assert = require('node:assert/strict');
const { test } = require('node:test');

test('HTTPS development proxy verifies the renewed certificate hostname', () => {
  const proxy = require('../proxy.https.cjs')['/api'];
  assert.equal(proxy.target, process.env.API_UPSTREAM || 'https://localhost:8090');
  assert.equal(proxy.secure, true);
  assert.equal(proxy.changeOrigin, false);
  assert.equal(
    proxy.agent.options.servername,
    process.env.TLS_SERVER_NAME || 'tertiaryverify.dedicated.co.za',
  );
});

test('HTTP development command keeps the HTTP backend proxy', () => {
  const proxy = require('../proxy.conf.json')['/api'];
  const { scripts } = require('../package.json');
  assert.equal(proxy.target, 'http://localhost:8090');
  assert.match(scripts['start:http'], /--ssl=false.*--proxy-config proxy\.conf\.json/);
  assert.equal(scripts.start, 'npm run start:https');
  assert.match(scripts['start:https'], /--ssl .*--proxy-config proxy\.https\.cjs/);
});

test('hosted development proxy targets the same service as the mobile app', () => {
  const { readFileSync } = require('node:fs');
  const { resolve } = require('node:path');
  const proxy = require('../proxy.hosted.json')['/api'];
  const { scripts } = require('../package.json');
  const mobile = readFileSync(
    resolve(__dirname, '../../poultry_pal_plus_app/lib/service/poultry_pal_service.dart'),
    'utf8',
  );
  const activeUrls = [...mobile.matchAll(/^\s*final String (?:auth|farm)BaseUrl = '([^']+)';/gm)]
    .map((match) => new URL(match[1]).origin);
  assert.equal(activeUrls.length, 2);
  for (const origin of activeUrls) assert.equal(proxy.target, origin);
  assert.equal(proxy.changeOrigin, true);
  assert.match(scripts['start:hosted'], /--ssl=false.*--proxy-config proxy\.hosted\.json/);
});
