import { waitForServiceWorker } from '../../e2e/helpers';
import { expect, test } from '../fixtures';
import { dialog, marker } from '../pages/records';

/** Offline-first behaviour against the real backend: records are kept locally, then synced. */
test.describe('sync center and offline work', () => {
  test('an idle farm reports everything synced', async ({ seededFarm, signInAs, page, shot }) => {
    await signInAs(seededFarm.owner, '/sync');
    await expect(page.getByRole('heading', { name: 'Everything is synced' })).toBeVisible();
    await expect(page.getByRole('heading', { name: /Waiting to sync/ })).toContainText('0');
    await expect(page.getByText('Nothing waiting')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Sync now' })).toBeEnabled();
    await shot(page, 'sync', 'synced');
  });

  test('a sale recorded offline is kept, shown as waiting, then reaches the backend', async ({
    freshFarm,
    farmApi,
    signInAs,
    shell,
    page,
    context,
    shot,
  }) => {
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    await api.createCoop({ coopName: 'Offline Coop', numberOfChickens: 300 });
    await signInAs(farm.owner, '/coops');
    await expect(page.getByTestId('coop-card')).toHaveCount(1);
    await waitForServiceWorker(page);
    await expect(page.getByTestId('coop-card')).toHaveCount(1);

    await context.setOffline(true);
    await shell.goTo('Sales');
    await expect(page.getByRole('heading', { name: 'Sales', level: 1 })).toBeVisible();
    await page.getByRole('button', { name: 'Record sale' }).first().click();
    const form = dialog(page, 'Record a sale');
    const buyer = marker('Offline buyer');
    await form.getByRole('combobox', { name: 'Packaging' }).click();
    await page.getByRole('option', { name: 'Tray of 30 eggs' }).click();
    await form.getByLabel('Number of trays sold').fill('3');
    await form.getByLabel('Price per tray').fill('40');
    await form.getByLabel('Additional info').fill(buyer);
    await form.getByRole('button', { name: 'Save sale' }).click();
    await expect(form).toBeHidden();

    const row = page.getByTestId('sale-row').filter({ hasText: buyer });
    await expect(row).toContainText('Waiting to sync');
    await shot(page, 'sync', 'offline-sale-waiting');
    expect((await api.snapshot()).sales.some((s) => s['additionalInfo'] === buyer)).toBe(false);

    await shell.goTo('Sync center');
    await expect(page.getByRole('heading', { name: "You're offline" })).toBeVisible();
    await expect(page.getByRole('heading', { name: /Waiting to sync/ })).toContainText('1');
    await expect(page.getByRole('button', { name: 'Sync now' })).toBeDisabled();
    await shot(page, 'sync', 'offline');

    await context.setOffline(false);
    await expect(page.getByRole('heading', { name: 'Everything is synced' })).toBeVisible({
      timeout: 60_000,
    });
    const saved = await api.eventually(
      (s) => s.sales.find((x) => x['additionalInfo'] === buyer),
      'offline sale',
    );
    expect(saved['totalSaleAmount']).toBe(120);
    await shell.goTo('Sales');
    await expect(row).toContainText('Synced');
  });

  test('offline records survive a reload and sync once the connection returns', async ({
    diagnostics,
    freshFarm,
    farmApi,
    signInAs,
    shell,
    page,
    context,
  }) => {
    // Reloading while offline makes the service worker answer API fetches with 504.
    diagnostics.expect({ status: 504 });
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    await api.createCoop({ coopName: 'Reload Coop', numberOfChickens: 200 });
    await signInAs(farm.owner, '/coops');
    await expect(page.getByTestId('coop-card')).toHaveCount(1);
    await waitForServiceWorker(page);

    await context.setOffline(true);
    await shell.goTo('Mortality');
    await page.getByRole('button', { name: 'Record mortality' }).first().click();
    const form = dialog(page, 'Record mortality');
    const reason = marker('Offline loss');
    await form.getByLabel('Number of deaths').fill('4');
    await form.getByLabel('Reason').fill(reason);
    await form.getByRole('button', { name: 'Save record' }).click();
    await expect(form).toBeHidden();

    await page.reload();
    const row = page.getByTestId('mortality-row').filter({ hasText: reason });
    await expect(row).toContainText('Waiting to sync');

    await context.setOffline(false);
    await api.eventually(
      (s) => s.mortalities.find((m) => m['reason'] === reason),
      'offline loss',
      60_000,
    );
    await expect(row).toContainText('Synced', { timeout: 60_000 });
  });

  test('download a fresh copy keeps data and confirms first', async ({
    seededFarm,
    signInAs,
    page,
  }) => {
    await signInAs(seededFarm.owner, '/sync');
    await page.getByRole('button', { name: 'Download fresh copy' }).click();
    const confirm = dialog(page, 'Download a fresh copy?');
    await expect(confirm).toBeVisible();
    await confirm.getByRole('button', { name: 'Cancel' }).click();
    await expect(confirm).toBeHidden();
    await page.getByRole('button', { name: 'Download fresh copy' }).click();
    await dialog(page, 'Download a fresh copy?').getByRole('button').last().click();
    await page.goto('/coops');
    await expect(page.getByTestId('coop-card')).toHaveCount(2);
  });
});
