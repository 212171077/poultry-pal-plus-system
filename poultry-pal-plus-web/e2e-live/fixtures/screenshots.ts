import { Page, TestInfo } from '@playwright/test';
import { mkdirSync, readdirSync, rmSync } from 'node:fs';
import { resolve } from 'node:path';
import { OUTPUT_DIR } from '../infra/env';

export const SCREENSHOT_DIR = resolve(OUTPUT_DIR, 'screenshots');

export const slug = (text: string): string =>
  text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);

/** Waits until the page has settled: network quiet, fonts loaded, spinners and animations done. */
export async function settle(page: Page): Promise<void> {
  await page.waitForLoadState('networkidle').catch(() => undefined);
  await page.evaluate(() => document.fonts.ready);
  await page
    .locator('mat-spinner, mat-progress-spinner, mat-progress-bar, [aria-busy="true"]')
    .first()
    .waitFor({ state: 'hidden', timeout: 10_000 })
    .catch(() => undefined);
  await page.evaluate(() =>
    Promise.all(
      document
        .getAnimations()
        .filter((a) => a.effect?.getComputedTiming().iterations !== Infinity)
        .map((a) => a.finished.catch(() => undefined)),
    ),
  );
}

/** Next capture number in a folder, read from disk so it survives worker restarts. */
function nextNumber(dir: string, name: string): number {
  let highest = 0;
  for (const file of readdirSync(dir)) {
    const match = /^(\d+)-(.+)\.png$/.exec(file);
    if (!match) continue;
    if (match[2] === name) rmSync(resolve(dir, file));
    else highest = Math.max(highest, Number(match[1]));
  }
  return highest + 1;
}

export type Shot = (page: Page, pageName: string, scenario?: string) => Promise<string>;

/** `<n>-<pageName>--<scenario>.png` (n = capture order) under screenshots/<desktop|mobile>/. */
export function makeShot(testInfo: TestInfo): Shot {
  return async (page, pageName, scenario = 'loaded') => {
    await settle(page);
    const dir = resolve(SCREENSHOT_DIR, testInfo.project.name);
    mkdirSync(dir, { recursive: true });
    const name = `${slug(pageName)}--${slug(scenario)}`;
    const path = resolve(dir, `${nextNumber(dir, name)}-${name}.png`);
    await page.screenshot({ path, fullPage: true, animations: 'disabled' });
    await testInfo.attach(`${pageName} (${scenario})`, { path, contentType: 'image/png' });
    return path;
  };
}

/** Screenshot of every open page for a failed test: screenshots/failures/<project>/. */
export async function captureFailure(pages: Page[], testInfo: TestInfo): Promise<void> {
  const dir = resolve(SCREENSHOT_DIR, 'failures', testInfo.project.name);
  mkdirSync(dir, { recursive: true });
  for (const [index, page] of pages.entries()) {
    if (page.isClosed()) continue;
    const path = resolve(dir, `${slug(testInfo.titlePath.slice(1).join(' '))}-${index + 1}.png`);
    await page.screenshot({ path, fullPage: true, animations: 'disabled' }).catch(() => undefined);
    await testInfo
      .attach(`failure-${index + 1}`, { path, contentType: 'image/png' })
      .catch(() => undefined);
  }
}
