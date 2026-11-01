import { expect, test } from '@playwright/test';
import { signIn, useOwnFarm, waitForServiceWorker } from './helpers';

test.beforeEach(async ({ context, baseURL }, testInfo) => {
  await useOwnFarm(context, baseURL, testInfo);
});

test('shows the dashboard with the app shell after signing in', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveURL(/\/login\?returnUrl=%2Fdashboard$/);
  await signIn(page);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(
    /Good (morning|afternoon|evening), Thandi/,
  );
  await expect(page).toHaveTitle('Dashboard · Poultry Pal Plus');
  await expect(page.getByRole('link', { name: /Sync status/ })).toBeVisible();
});

test('keeps working offline after the first visit', async ({ page, context }) => {
  await signIn(page);
  await waitForServiceWorker(page);

  await context.setOffline(true);
  await page.reload();

  await expect(page.getByRole('heading', { level: 1 })).toHaveText(
    /Good (morning|afternoon|evening)/,
  );
  await expect(page.getByRole('status').filter({ hasText: "You're offline" })).toBeVisible();

  // Lazy-loaded feature routes are precached too.
  await page.goto('/sales');
  await expect(page.getByRole('heading', { level: 1, name: 'Sales' })).toBeVisible();
});

test('adapts navigation to the screen size', async ({ page, isMobile }) => {
  await signIn(page);
  const main = page.getByRole('navigation', { name: 'Main' });
  if (isMobile) {
    await expect(main.getByRole('button', { name: 'Quick add' })).toBeVisible();
  } else {
    await expect(main.getByRole('link', { name: 'Coops & batches' })).toBeVisible();
  }
});
