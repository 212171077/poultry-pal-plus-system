import { BrowserContext, Page, TestInfo, expect } from '@playwright/test';

export const EMAIL = 'thandi@example.com';
export const PASSWORD = 'secret1';

/**
 * Waits until the service worker has cached every prefetched asset. Until then Angular's worker
 * holds back requests from the page (lazy chunks, API calls), which makes first visits slow.
 */
async function waitForAppCached(page: Page): Promise<void> {
  await page.evaluate(async () => {
    const manifest = (await (await fetch('/ngsw.json?ngsw-bypass=true')).json()) as {
      assetGroups: { name: string; installMode: string; urls: string[] }[];
    };
    const groups = manifest.assetGroups.filter((group) => group.installMode === 'prefetch');
    const cached = async (group: { name: string; urls: string[] }): Promise<boolean> => {
      const name = (await caches.keys()).find((key) => key.endsWith(`:assets:${group.name}:cache`));
      return !!name && (await (await caches.open(name)).keys()).length >= group.urls.length;
    };
    const deadline = Date.now() + 30_000;
    while (!(await Promise.all(groups.map(cached))).every(Boolean)) {
      if (Date.now() > deadline) throw new Error('Service worker did not finish caching the app');
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  });
}

/** Opens a page and waits until the service worker has cached the whole app. */
export async function openApp(page: Page, path: string): Promise<void> {
  await page.goto(path);
  await waitForAppCached(page);
}

/** Makes sure the service worker controls the page, so a reload works offline. */
export async function waitForServiceWorker(page: Page): Promise<void> {
  await waitForAppCached(page);
  // The first visit is not controlled yet; reload so the service worker serves the app.
  await page.reload();
  await page.waitForFunction(() => navigator.serviceWorker.controller !== null);
}

/** Gives the test its own farm on the mock backend (see e2e/mock-api.mjs). */
export async function useOwnFarm(
  context: BrowserContext,
  baseURL: string | undefined,
  testInfo: TestInfo,
): Promise<string> {
  const tenant = `${testInfo.project.name}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  await context.addCookies([{ name: 'pp_mock_tenant', value: tenant, url: baseURL }]);
  return tenant;
}

/** Signs in through the login page and waits for the requested page (the dashboard by default). */
export async function signIn(
  page: Page,
  { returnTo = '/dashboard', rememberMe = true }: { returnTo?: string; rememberMe?: boolean } = {},
): Promise<void> {
  await openApp(page, returnTo);
  await expect(page).toHaveURL(/\/login/);
  await page.getByLabel('Email').fill(EMAIL);
  await page.getByLabel('Password', { exact: true }).fill(PASSWORD);
  if (!rememberMe) await page.getByLabel('Keep me signed in on this device').uncheck();
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page).toHaveURL(new RegExp(`${returnTo.replace(/[?]/g, '\\?')}$`), {
    timeout: 15_000,
  });
}
