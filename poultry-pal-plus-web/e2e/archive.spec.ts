import { expect, test } from '@playwright/test';
import { signIn, useOwnFarm } from './helpers';

test.beforeEach(async ({ context, baseURL, page }, testInfo) => {
  await useOwnFarm(context, baseURL, testInfo);
  await signIn(page);
});

test('the coops page links to the archived batches', async ({ page }) => {
  await page.goto('/coops');
  await page.getByRole('link', { name: 'Archived batches' }).click();
  await expect(page.getByRole('heading', { name: 'Archived batches' })).toBeVisible();
  await expect(page.getByTestId('archived-batch')).toHaveCount(1);
  await expect(page.getByText('Old broilers')).toBeVisible();
  await expect(page.getByText('10 (5.0%)')).toBeVisible();
});
