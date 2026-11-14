import { defineConfig, devices } from '@playwright/test';
import { resolve } from 'node:path';
import { OUTPUT_DIR, urls } from './infra/env';

/** Visible browser with a pause before every action, so a person can follow. E2E_HEADLESS=1 turns it off. */
const headless = process.env['E2E_HEADLESS'] === '1';
const slowMo = headless ? 0 : Number(process.env['E2E_SLOWMO'] ?? 800);

/**
 * Live suite: real backend, real MongoDB and Mailpit in Docker (see docker-compose.e2e.yml).
 * Global setup builds and starts the stack, global teardown removes it. No API mocking.
 */
export default defineConfig({
  testDir: './specs',
  outputDir: resolve(OUTPUT_DIR, 'artifacts'),
  globalSetup: './global-setup.ts',
  globalTeardown: './global-teardown.ts',
  fullyParallel: false,
  workers: 1,
  forbidOnly: !!process.env['CI'],
  retries: 1,
  // Every action waits slowMo ms, so slowed runs get a much larger per-test budget.
  timeout: slowMo > 0 ? 600_000 : 60_000,
  expect: { timeout: 10_000 },
  reporter: [
    ['list'],
    ['./infra/summary-reporter.ts'],
    ['html', { outputFolder: resolve(OUTPUT_DIR, 'reports', 'html'), open: 'never' }],
  ],
  use: {
    headless,
    launchOptions: { slowMo },
    baseURL: urls.web,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'desktop',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1920, height: 1080 } },
    },
    { name: 'mobile', use: { ...devices['Pixel 7'], viewport: { width: 390, height: 844 } } },
  ],
});
