import { defineConfig } from '@playwright/test';
import { resolve } from 'node:path';
import { OUTPUT_DIR } from './infra/env';
import base from './playwright.live.config';

/**
 * Reproduces the documented application defects (tests tagged @DEF-###) with a video of each one.
 * Same stack and fixtures as the live suite; visible browser, slower than the regression run.
 * E2E_SLOWMO overrides the pause; E2E_HEADLESS=1 hides the window (videos are still recorded).
 */
const headless = process.env['E2E_HEADLESS'] === '1';
const slowMo = Number(process.env['E2E_SLOWMO'] ?? 1500);

export default defineConfig({
  ...base,
  grep: /@DEF-/,
  retries: 0,
  timeout: 600_000,
  outputDir: resolve(OUTPUT_DIR, 'defect-artifacts'),
  reporter: [['list'], ['./infra/defect-video-reporter.ts']],
  use: { ...base.use, headless, launchOptions: { slowMo } },
  projects: (base.projects ?? []).map((project) => {
    const viewport = project.use?.viewport ?? { width: 1280, height: 720 };
    return {
      ...project,
      use: { ...project.use, video: { mode: 'on', size: viewport } },
    };
  }),
});
