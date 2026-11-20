import { newApi, signInApi } from '../infra/api';
import { expect, test } from '../fixtures';

const toast = (page: import('@playwright/test').Page, text: string | RegExp) =>
  page.locator('mat-snack-bar-container').filter({ hasText: text });

test.describe('settings and account', () => {
  test('the profile can be edited and shows in the account menu', async ({
    freshFarm,
    signInAs,
    shell,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    await signInAs(farm.owner, '/settings');
    await expect(page.getByRole('heading', { name: 'Settings', level: 1 })).toBeVisible();
    await page.getByLabel('First name').fill('Renamed');
    await page.getByLabel('Phone number').fill('0821234567');
    await page.getByRole('button', { name: 'Save profile' }).click();
    await expect(toast(page, 'Your profile was updated.')).toBeVisible();
    await shot(page, 'settings', 'profile-saved');
    await page.reload();
    await expect(page.getByLabel('First name')).toHaveValue('Renamed');
    expect(await shell.accountSummary()).toContain('Renamed');
  });

  test('the password change validates, rejects a wrong current password and works', async ({
    freshFarm,
    signInAs,
    shell,
    loginPage,
    page,
    diagnostics,
  }) => {
    diagnostics.expect({ status: 400 });
    diagnostics.expect({ status: 401 });
    diagnostics.expect({ status: 403 });
    const farm = await freshFarm();
    await signInAs(farm.owner, '/settings');
    const current = page.getByLabel('Current password');
    const next = page.getByLabel('New password', { exact: true });
    const confirm = page.getByLabel('Confirm new password');

    await current.fill(farm.owner.password);
    await next.fill('short');
    await confirm.focus();
    await expect(page.getByText(/Use at least 8 characters/)).toBeVisible();

    await next.fill('Brand-new-Pass1!');
    await confirm.fill('Different-pass1');
    await page.getByRole('button', { name: 'Change password' }).click();
    await expect(toast(page, 'The new passwords do not match.')).toBeVisible();

    // The form enforces the server's password rules (DEF-011) before anything is sent.
    await next.fill('alllowercase1');
    await confirm.fill('alllowercase1');
    await current.fill(farm.owner.password);
    await page.getByRole('button', { name: 'Change password' }).click();
    await expect(page.getByText(/upper-case letter/)).toBeVisible();
    await expect(toast(page, 'Your password was changed.')).toHaveCount(0);

    await next.fill('Brand-new-Pass1!');
    await confirm.fill('Brand-new-Pass1!');
    await current.fill('wrong-current-pass');
    await page.getByRole('button', { name: 'Change password' }).click();
    await expect(toast(page, 'Your password was changed.')).toHaveCount(0);

    await current.fill(farm.owner.password);
    await page.getByRole('button', { name: 'Change password' }).click();
    await expect(toast(page, 'Your password was changed.')).toBeVisible();

    const fresh = await newApi();
    await signInApi(fresh, { email: farm.owner.email, password: 'Brand-new-Pass1!' });
    await fresh.dispose();
    await shell.signOut();
    await loginPage.goto('/login');
    await loginPage.signIn({ email: farm.owner.email, password: farm.owner.password });
    await expect(loginPage.error).toBeVisible();
  });

  // DEFECT: a new farm has detailsVersion 0, so the server never sends the farm snapshot and the
  // Farm details form stays empty (saving then silently does nothing).
  test(
    'farm details and currency are saved for the farm',
    { tag: '@DEF-002' },
    async ({ freshFarm, farmApi, signInAs, page }) => {
      const farm = await freshFarm();
      const api = await farmApi(farm.owner);
      await signInAs(farm.owner, '/settings');
      await expect(page.getByLabel('Farm name')).not.toHaveValue('');
      await page.getByLabel('Farm name').fill('Renamed Farm E2E');
      await page.getByRole('button', { name: 'Save farm details' }).click();
      await expect(toast(page, 'Farm details were updated.')).toBeVisible();
      await expect.poll(() => api.farmName(), { timeout: 30_000 }).toBe('Renamed Farm E2E');

      await page.getByRole('combobox', { name: 'Currency' }).click();
      await page.getByRole('option').nth(1).click();
      await page.getByRole('button', { name: 'Save currency' }).click();
      await expect(toast(page, 'Currency preference saved.')).toBeVisible();
    },
  );

  test('workers cannot see farm details', async ({ sharedFarm, signInAs, page }) => {
    await signInAs(sharedFarm.worker, '/settings');
    await expect(page.getByRole('heading', { name: 'Your profile' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Farm details' })).toHaveCount(0);
  });

  test('the appearance choice is remembered across reloads', async ({
    sharedFarm,
    signInAs,
    page,
    shot,
  }) => {
    await signInAs(sharedFarm.owner, '/settings');
    await page.getByRole('radio', { name: /Farm night/ }).click();
    await shot(page, 'settings', 'dark');
    await page.reload();
    await expect(page.getByRole('radio', { name: /Farm night/ })).toBeChecked();
  });

  test('Meadow replaces the duplicate Light theme', async ({ sharedFarm, signInAs, page }) => {
    await signInAs(sharedFarm.owner, '/settings');
    await expect(page.getByRole('radio', { name: /^Light/ })).toHaveCount(0);
    await page.getByRole('radio', { name: /Meadow/ }).click();
    await expect(page.locator('html')).toHaveClass(/theme-meadow/);
  });
});
