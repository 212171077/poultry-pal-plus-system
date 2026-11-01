import { expect, test } from '@playwright/test';
import { signIn, useOwnFarm, waitForServiceWorker } from './helpers';

test.beforeEach(async ({ context, baseURL, page }, testInfo) => {
  await useOwnFarm(context, baseURL, testInfo);
  await signIn(page);
});

test('the dashboard, reminders and reports work without a network connection', async ({
  page,
  context,
}) => {
  test.slow();
  await page.goto('/sync');
  await waitForServiceWorker(page);
  await expect(page.getByRole('heading', { name: 'Everything is synced' })).toBeVisible();

  await context.setOffline(true);
  await page.goto('/dashboard');
  await expect(page.getByText('Live birds')).toBeVisible();
  await expect(page.getByText('500', { exact: true })).toBeVisible();
  await expect(page.getByTestId('due-reminder')).toHaveCount(2);
  await page.getByRole('radio', { name: '7 days' }).click();

  await page.goto('/reminders');
  await expect(page.getByTestId('reminder-row')).toHaveCount(2);
  await expect(page.getByText('Newcastle booster')).toBeVisible();
  await expect(page.getByText(/Overdue/)).toBeVisible();
  await page.getByRole('button', { name: 'Complete Newcastle booster' }).click();
  const dialog = page.getByRole('dialog', { name: 'Mark as completed' });
  await dialog.getByLabel('Comment (optional)').fill('Done by Thandi');
  await dialog.getByRole('button', { name: 'Mark completed' }).click();
  await expect(page.getByTestId('reminder-row')).toHaveCount(1);
  await page.getByRole('radio', { name: /Completed/ }).click();
  await expect(page.getByText('Done by Thandi')).toBeVisible();

  await page.goto('/reports');
  await expect(page.getByTestId('coop-report').getByText('Layer House A')).toBeVisible();
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: 'CSV' }).click();
  expect((await download).suggestedFilename()).toMatch(/\.csv$/);

  await expect(page.getByRole('button', { name: 'Report PDF' })).toBeDisabled();
  await page.getByRole('button', { name: 'Email report' }).click();
  await expect(page.getByTestId('report-queue').getByText('Farm report')).toBeVisible();
});
