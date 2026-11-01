import { expect, test } from '@playwright/test';
import { signIn, useOwnFarm } from './helpers';

test.beforeEach(async ({ context, baseURL, page }, testInfo) => {
  await useOwnFarm(context, baseURL, testInfo);
  await signIn(page);
});

test('team management shows roles, status and coop assignments', async ({ page }) => {
  await page.goto('/team');
  await expect(page.getByRole('heading', { name: 'Team', exact: true })).toBeVisible();
  await expect(page.getByText('Sipho Dlamini')).toBeVisible();
  await expect(page.getByText('Farm worker')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Deactivate' })).toBeVisible();
  await expect(page.getByLabel('Assigned coops for Sipho')).toBeVisible();
});

test('settings expose profile, farm, currency, storage and update controls', async ({ page }) => {
  await page.goto('/settings');
  await expect(page.getByRole('heading', { name: 'Your profile' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Farm details' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Currency' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Local storage' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Clear local data' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Check for updates' })).toBeVisible();
});
