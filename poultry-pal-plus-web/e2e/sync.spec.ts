import { expect, test } from '@playwright/test';
import { signIn, useOwnFarm, waitForServiceWorker } from './helpers';

const RECORDS = 20;

test.beforeEach(async ({ context, baseURL, page }, testInfo) => {
  await useOwnFarm(context, baseURL, testInfo);
  await signIn(page);
});

test('records created offline survive a reload and sync when back online', async ({
  page,
  context,
}, testInfo) => {
  test.slow();
  const marker = `e2e-${testInfo.project.name}-${Date.now()}`;

  await page.goto('/sync');
  await waitForServiceWorker(page);
  await expect(page.getByRole('heading', { name: 'Everything is synced' })).toBeVisible();

  await page.goto('/expenses');
  await expect(page.getByRole('heading', { level: 1, name: 'Expenses' })).toBeVisible();

  await context.setOffline(true);
  for (let i = 1; i <= RECORDS; i++) {
    await page.getByRole('button', { name: 'Add expense' }).click();
    const dialog = page.getByRole('dialog', { name: 'Add expense' });
    await dialog.getByRole('combobox', { name: 'Expense type' }).click();
    await page.getByRole('option', { name: 'Feed Costs' }).click();
    await dialog.getByLabel('Amount').fill(String(100 + i));
    await dialog.getByLabel('Notes').fill(`${marker} #${i}`);
    await dialog.getByRole('button', { name: 'Save expense' }).click();
    await expect(dialog).toBeHidden();
  }

  const rows = page.getByTestId('expense-row').filter({ hasText: marker });
  await expect(rows).toHaveCount(RECORDS);
  await expect(rows.filter({ hasText: 'Waiting to sync' })).toHaveCount(RECORDS);

  await page.reload();
  await expect(rows).toHaveCount(RECORDS);
  await expect(rows.filter({ hasText: 'Waiting to sync' })).toHaveCount(RECORDS);

  await context.setOffline(false);
  await expect(rows.filter({ hasText: 'Synced' })).toHaveCount(RECORDS, { timeout: 20_000 });

  const response = await page.request.get(`/__mock/records?type=EXPENSE&marker=${marker}`);
  const saved = (await response.json()) as { additionalInfo: string; amount: number }[];
  expect(saved).toHaveLength(RECORDS);
  expect(new Set(saved.map((record) => record.additionalInfo)).size).toBe(RECORDS);
});

test('pulls changes made on another device', async ({ page, request }) => {
  await page.goto('/expenses');
  await expect(page.getByRole('heading', { level: 1, name: 'Expenses' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'No expenses yet' })).toBeVisible();

  // Simulate the mobile app pushing an expense for the same farm.
  const cookies = await page.context().cookies();
  const tenant = cookies.find((cookie) => cookie.name === 'pp_mock_tenant')?.value ?? '';
  await request.post(`/api/v1/sync/push?tenant=${tenant}`, {
    data: {
      operations: [
        {
          opId: `op-${Date.now()}`,
          entityType: 'EXPENSE',
          operation: 'UPSERT',
          entityId: `remote-${Date.now()}`,
          coopId: 'coop-1',
          baseVersion: null,
          payload: {
            expenseDate: new Date().toISOString(),
            expenseType: 'Labor Costs',
            amount: 450,
            additionalInfo: 'Added on the phone',
          },
        },
      ],
    },
  });

  // Coming back to the tab triggers a pull.
  await page.goto('/sync');
  await page.getByRole('button', { name: 'Sync now' }).click();
  await page.goto('/expenses');
  await expect(
    page.getByTestId('expense-row').filter({ hasText: 'Added on the phone' }),
  ).toHaveCount(1);
});
