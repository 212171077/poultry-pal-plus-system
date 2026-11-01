import { expect, test } from '@playwright/test';
import { EMAIL, openApp, signIn, useOwnFarm, waitForServiceWorker } from './helpers';

test.beforeEach(async ({ context, baseURL }, testInfo) => {
  await useOwnFarm(context, baseURL, testInfo);
});

test('rejects a wrong password with a clear message', async ({ page }) => {
  await openApp(page, '/login');
  await page.getByLabel('Email').fill(EMAIL);
  await page.getByLabel('Password', { exact: true }).fill('wrong-password');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page.getByRole('alert')).toHaveText('Email or password is incorrect.');
  await expect(page).toHaveURL(/\/login$/);
});

test('returns to the requested page after signing in', async ({ page }) => {
  await signIn(page, { returnTo: '/expenses' });
  await expect(page.getByRole('heading', { level: 1, name: 'Expenses' })).toBeVisible();
});

// Phase 3 exit criterion: a user who signed in before can reopen the app offline and keep working.
test('reopens offline after a previous sign-in and records an expense', async ({
  page,
  context,
}) => {
  await signIn(page);
  await waitForServiceWorker(page);
  await page.goto('/sync');
  await expect(page.getByRole('heading', { name: 'Everything is synced' })).toBeVisible();

  await context.setOffline(true);
  await page.goto('/');
  await expect(page).toHaveURL(/\/dashboard$/);
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(/, Thandi$/);

  await page.goto('/expenses');
  await page.getByRole('button', { name: 'Add expense' }).click();
  const dialog = page.getByRole('dialog', { name: 'Add expense' });
  await dialog.getByRole('combobox', { name: 'Expense type' }).click();
  await page.getByRole('option', { name: 'Feed Costs' }).click();
  await dialog.getByLabel('Amount').fill('75');
  await dialog.getByLabel('Notes').fill('Bought offline');
  await dialog.getByRole('button', { name: 'Save expense' }).click();
  await expect(page.getByTestId('expense-row').filter({ hasText: 'Bought offline' })).toContainText(
    'Waiting to sync',
  );
});

test('signing out wipes the device and returns to sign-in', async ({ page }) => {
  await signIn(page);
  await page.getByRole('button', { name: /Account menu/ }).click();
  await expect(page.getByRole('menu')).toContainText('Farm owner · Sunrise Poultry');
  await page.getByRole('menuitem', { name: 'Sign out' }).click();
  await expect(page).toHaveURL(/\/login$/);

  await page.goto('/dashboard');
  await expect(page).toHaveURL(/\/login\?returnUrl=%2Fdashboard$/);
  const users = await page.evaluate(
    () =>
      new Promise<number>((resolve) => {
        const open = indexedDB.open('poultry-pal');
        open.onsuccess = () => {
          const tx = open.result.transaction('users', 'readonly');
          const count = tx.objectStore('users').count();
          count.onsuccess = () => resolve(count.result);
        };
        open.onerror = () => resolve(-1);
      }),
  );
  expect(users).toBe(0);
});

test('warns before signing out with unsynced changes', async ({ page, context }) => {
  await signIn(page);
  await waitForServiceWorker(page);
  await page.goto('/expenses');
  await expect(page.getByRole('heading', { level: 1, name: 'Expenses' })).toBeVisible();
  await context.setOffline(true);
  await page.getByRole('button', { name: 'Add expense' }).click();
  const dialog = page.getByRole('dialog', { name: 'Add expense' });
  await dialog.getByRole('combobox', { name: 'Expense type' }).click();
  await page.getByRole('option', { name: 'Feed Costs' }).click();
  await dialog.getByLabel('Amount').fill('10');
  await dialog.getByRole('button', { name: 'Save expense' }).click();
  await expect(dialog).toBeHidden();

  await page.getByRole('button', { name: /Account menu/ }).click();
  await page.getByRole('menuitem', { name: 'Sign out' }).click();
  const confirm = page.getByRole('dialog', { name: 'Sign out and lose unsynced changes?' });
  await expect(confirm).toContainText('1 change has not reached the server');
  await confirm.getByRole('button', { name: 'Stay signed in' }).click();
  await expect(page).toHaveURL(/\/expenses$/);
});

test('registers a new farm and waits for administrator approval', async ({ page }) => {
  const email = `owner-${Date.now()}@example.com`;
  await openApp(page, '/login');
  await page.getByRole('link', { name: 'Create a farm account' }).click();
  await expect(page).toHaveURL(/\/register$/);

  await page.getByLabel('Farm name').fill('Green Valley Eggs');
  await page.getByLabel('First name').fill('Lerato');
  await page.getByLabel('Surname').fill('Nkosi');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Phone number').fill('0821234567');
  await page.getByLabel('Password', { exact: true }).fill('Layers2026!');
  await page.getByLabel('Confirm password').fill('Layers2026!');
  await expect(page.getByText('Strength: Strong')).toBeVisible();
  await page.getByRole('button', { name: 'Create account' }).click();

  await expect(page.getByText('awaiting approval by the administrator')).toBeVisible();

  // The same email can't register twice.
  await page.goto('/register');
  await page.getByLabel('Farm name').fill('Another farm');
  await page.getByLabel('First name').fill('Lerato');
  await page.getByLabel('Surname').fill('Nkosi');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Phone number').fill('0821234567');
  await page.getByLabel('Password', { exact: true }).fill('Layers2026!');
  await page.getByLabel('Confirm password').fill('Layers2026!');
  await page.getByRole('button', { name: 'Create account' }).click();
  await expect(page.getByText('An account with this email already exists')).toBeVisible();
});

test('resets a forgotten password with the emailed code', async ({ page }) => {
  await openApp(page, '/login');
  await page.getByRole('link', { name: 'Forgot your password?' }).click();
  await expect(page).toHaveURL(/\/forgot-password$/);

  await page.getByLabel('Email').fill('someone@example.com');
  await page.getByRole('button', { name: 'Send reset code' }).click();

  await page.getByLabel('6-digit code').fill('000000');
  await page.getByLabel('New password').fill('NewLayers2026!');
  await page.getByRole('button', { name: 'Set new password' }).click();
  await expect(page.getByText('The code is invalid or has expired')).toBeVisible();

  await page.getByLabel('6-digit code').fill('123456');
  await page.getByRole('button', { name: 'Set new password' }).click();
  await expect(page).toHaveURL(/\/login$/);
});
