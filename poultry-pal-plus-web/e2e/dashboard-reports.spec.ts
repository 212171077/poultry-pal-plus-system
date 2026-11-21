import { expect, test } from '@playwright/test';
import { signIn, useOwnFarm, waitForServiceWorker } from './helpers';

test.beforeEach(async ({ context, baseURL, page }, testInfo) => {
  await useOwnFarm(context, baseURL, testInfo);
  await signIn(page);
});

test('the dashboard lists "All" first and selects it by default', async ({ page }) => {
  const options = page.getByRole('radio');
  await expect(options.first()).toHaveAccessibleName(/All/);
  await expect(page.getByRole('radio', { name: /All/ })).toBeChecked();
  await expect(page.getByTestId('range-summary')).toHaveText('Summary for all recorded data');
  await page.getByRole('radio', { name: '7 days' }).click();
  await expect(page.getByTestId('range-summary')).toHaveText('Summary for the last 7 days');
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
  await expect(
    page.getByRole('region', { name: 'Key figures' }).getByText('500', { exact: true }),
  ).toBeVisible();
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
  await expect(page.getByRole('radio', { name: /^All/ })).toBeChecked();
  const csv = page.getByRole('button', { name: 'CSV' });
  const excel = page.getByRole('button', { name: 'Excel' });
  const [csvBox, excelBox, emailBox] = await Promise.all([
    csv.boundingBox(),
    excel.boundingBox(),
    page.getByRole('button', { name: 'Email report' }).boundingBox(),
  ]);
  expect(csvBox!.y).toBe(excelBox!.y);
  expect(csvBox!.y).toBeGreaterThan(emailBox!.y);
  const download = page.waitForEvent('download');
  await csv.click();
  expect((await download).suggestedFilename()).toMatch(/\.csv$/);

  await expect(page.getByRole('button', { name: 'Report PDF' })).toBeDisabled();
  await page.getByRole('button', { name: 'Email report' }).click();
  await expect(page.getByTestId('report-queue').getByText('Farm report')).toBeVisible();
});
