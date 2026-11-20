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

test('owner adds, edits and deletes farm addresses from a dialog', async ({ page }) => {
  await page.goto('/settings');
  await expect(page.getByRole('heading', { name: 'Farm addresses' })).toBeVisible();
  await expect(page.getByText('No addresses yet.')).toBeVisible();

  await page.getByRole('button', { name: 'Add address' }).click();
  let dialog = page.getByRole('dialog', { name: 'Add address' });
  await dialog.getByRole('button', { name: 'Add address' }).click();
  await expect(dialog.getByText('Enter the first line of the address')).toBeVisible();
  await dialog.getByLabel('Label').fill('Main farm');
  await dialog.getByLabel('Address line 1').fill('1 Farm Road');
  await dialog.getByLabel('City / town').fill('Pretoria');
  await dialog.getByRole('button', { name: 'Add address' }).click();
  await expect(dialog).toBeHidden();
  const main = page.locator('app-address-card', { hasText: 'Main farm' });
  await expect(main.getByText('Primary')).toBeVisible();
  await expect(main.getByText('1 Farm Road')).toBeVisible();

  await page.getByRole('button', { name: 'Add address' }).click();
  dialog = page.getByRole('dialog', { name: 'Add address' });
  await dialog.getByLabel('Label').fill('Packing shed');
  await dialog.getByLabel('Address line 1').fill('2 Shed Lane');
  await dialog.getByRole('button', { name: 'Add address' }).click();
  await expect(page.locator('app-address-card')).toHaveCount(2);

  await page.getByRole('button', { name: 'Edit Packing shed' }).click();
  dialog = page.getByRole('dialog', { name: 'Edit address' });
  await expect(dialog.getByLabel('Address line 1')).toHaveValue('2 Shed Lane');
  await dialog.getByLabel('Label').fill('Cold room');
  await dialog.getByRole('button', { name: 'Save changes' }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByText('Cold room')).toBeVisible();
  await expect(page.getByText('Packing shed')).toHaveCount(0);

  await page.getByRole('button', { name: 'Delete Cold room' }).click();
  await page
    .getByRole('dialog', { name: 'Delete address?' })
    .getByRole('button', { name: 'Delete' })
    .click();
  await expect(page.locator('app-address-card')).toHaveCount(1);
  await expect(page.getByText('Cold room')).toHaveCount(0);
});
