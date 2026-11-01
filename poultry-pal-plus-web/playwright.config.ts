import { defineConfig, devices } from '@playwright/test';

const port = Number(process.env['E2E_PORT'] ?? 4300);
const ci = !!process.env['CI'];
/** Locally the browser opens so you can watch the tests; set E2E_HEADLESS=1 (or run in CI) to hide it. */
const headless = ci || process.env['E2E_HEADLESS'] === '1';
/** Pause in ms before each browser action when the browser is visible (override with E2E_SLOWMO). */
const slowMo = headless ? 0 : Number(process.env['E2E_SLOWMO'] ?? 1000);

/** E2E tests run against the production build (`npm run build`) so the service worker is active. */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  // One visible browser window at a time is easier to follow.
  workers: headless ? undefined : 1,
  forbidOnly: ci,
  retries: ci ? 1 : 0,
  reporter: ci ? 'github' : 'list',
  // Slowed-down runs need proportionally more time per test and per assertion.
  timeout: 30_000 + slowMo * 200,
  expect: { timeout: 5_000 + slowMo * 10 },
  use: {
    baseURL: `http://localhost:${port}`,
    trace: 'retain-on-failure',
    headless,
    launchOptions: { slowMo },
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'] } },
    { name: 'mobile', use: { ...devices['Pixel 7'] } },
  ],
  webServer: {
    command: `node e2e/serve.mjs`,
    env: { PORT: String(port) },
    url: `http://localhost:${port}`,
    reuseExistingServer: !ci,
  },
});
