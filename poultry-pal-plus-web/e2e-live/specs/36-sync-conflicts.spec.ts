import { BrowserContext, Locator, Page } from '@playwright/test';
import { FarmApi } from '../infra/farm-api';
import { waitForServiceWorker } from '../../e2e/helpers';
import { Account, expect, Farm, test } from '../fixtures';
import { choose, dialog, marker, rowAction } from '../pages/records';

interface SetupFixtures {
  freshFarm: () => Promise<Farm>;
  farmApi: (account: Account) => Promise<FarmApi>;
  signInAs: (account: Account, returnTo?: string) => Promise<void>;
  page: Page;
}

const MORTALITY_FIELDS = ['dateOccurred', 'numberOfDeaths', 'reason'];

/**
 * Conflicts and rejected operations. A second device is simulated by changing the record through
 * the API while the browser is offline, so the browser's queued change is based on a stale version.
 */
test.describe('sync center conflicts and failed changes', () => {
  test.beforeEach(({ diagnostics }) => {
    // While offline the service worker answers API fetches with 504.
    diagnostics.expect({ status: 504 });
  });

  async function setup({ freshFarm, farmApi, signInAs, page }: SetupFixtures, reason: string) {
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    const coopId = await api.createCoop({ coopName: 'Conflict Coop', numberOfChickens: 500 });
    const id = await api.addMortality(coopId, 5, reason);
    await signInAs(farm.owner, '/mortality');
    const row = page.getByTestId('mortality-row').filter({ hasText: reason });
    await expect(row).toContainText('Synced', { timeout: 30_000 });
    await waitForServiceWorker(page);
    return { farm, api, coopId, id, row };
  }

  async function editDeathsOffline(
    page: Page,
    row: Locator,
    context: BrowserContext,
    deaths: string | null,
    reason?: string,
  ) {
    await context.setOffline(true);
    await rowAction(row, page, 'Edit');
    const edit = dialog(page, 'Edit mortality record');
    if (deaths) await edit.getByLabel('Number of deaths').fill(deaths);
    if (reason) await edit.getByLabel('Reason').fill(reason);
    await edit.getByRole('button', { name: 'Save changes' }).click();
    await expect(edit).toBeHidden();
  }

  async function serverMortality(api: FarmApi, id: string) {
    const snapshot = await api.snapshot();
    const record = snapshot.mortalities.find((m) => m.id === id);
    expect(record, 'mortality on the backend').toBeTruthy();
    return record!;
  }

  test('a change to the same field on two devices needs review; keep mine wins', async ({
    freshFarm,
    farmApi,
    signInAs,
    shell,
    page,
    context,
    shot,
  }) => {
    const reason = marker('Conflict mine');
    const { api, id, row } = await setup({ freshFarm, farmApi, signInAs, page }, reason);
    await editDeathsOffline(page, row, context, '10');
    await expect(row).toContainText('Waiting to sync');

    await api.update(
      'MORTALITY',
      await serverMortality(api, id),
      { numberOfDeaths: 7 },
      MORTALITY_FIELDS,
    );

    await shell.goTo('Sync center');
    await context.setOffline(false);
    await expect(
      page.getByRole('heading', { name: 'Some changes need your attention' }),
    ).toBeVisible({ timeout: 60_000 });
    await expect(page.getByRole('heading', { name: /Needs your attention/ })).toContainText('1');
    await shot(page, 'sync', 'conflict-listed');

    await page.getByRole('button', { name: 'Review' }).click();
    const review = dialog(page, 'Review conflicting change');
    const table = review.getByRole('table', { name: 'Changed fields' });
    const deaths = table.getByRole('row').filter({ hasText: 'Number of deaths' });
    await expect(deaths.getByRole('cell').nth(0)).toHaveText('10');
    await expect(deaths.getByRole('cell').nth(1)).toHaveText('7');
    await shot(page, 'sync', 'conflict-review');

    await review.getByRole('button', { name: 'Keep mine' }).click();
    await expect(review).toBeHidden();
    await expect(page.getByRole('heading', { name: 'Everything is synced' })).toBeVisible({
      timeout: 60_000,
    });
    await expect(page.getByText('Nothing waiting')).toBeVisible();
    await expect
      .poll(async () => (await serverMortality(api, id))['numberOfDeaths'], { timeout: 30_000 })
      .toBe(10);

    await shell.goTo('Mortality');
    await expect(row).toContainText('10');
    await expect(row).toContainText('Synced');
  });

  test('keep server version discards the local change', async ({
    freshFarm,
    farmApi,
    signInAs,
    shell,
    page,
    context,
  }) => {
    const reason = marker('Conflict server');
    const { api, id, row } = await setup({ freshFarm, farmApi, signInAs, page }, reason);
    await editDeathsOffline(page, row, context, '12');
    await api.update(
      'MORTALITY',
      await serverMortality(api, id),
      { numberOfDeaths: 8 },
      MORTALITY_FIELDS,
    );

    await shell.goTo('Sync center');
    await context.setOffline(false);
    await expect(page.getByRole('button', { name: 'Review' })).toBeVisible({ timeout: 60_000 });
    await page.getByRole('button', { name: 'Review' }).click();
    const review = dialog(page, 'Review conflicting change');
    await review.getByRole('button', { name: 'Keep server version' }).click();
    await expect(review).toBeHidden();

    await expect(page.getByRole('heading', { name: 'Everything is synced' })).toBeVisible({
      timeout: 60_000,
    });
    expect((await serverMortality(api, id))['numberOfDeaths']).toBe(8);
    await shell.goTo('Mortality');
    await expect(row).toContainText('8');
    await expect(row).toContainText('Synced');
  });

  test('decide later keeps the conflict listed and the record flagged', async ({
    freshFarm,
    farmApi,
    signInAs,
    shell,
    page,
    context,
  }) => {
    const reason = marker('Conflict later');
    const { api, id, row } = await setup({ freshFarm, farmApi, signInAs, page }, reason);
    await editDeathsOffline(page, row, context, '15');
    await api.update(
      'MORTALITY',
      await serverMortality(api, id),
      { numberOfDeaths: 9 },
      MORTALITY_FIELDS,
    );

    await shell.goTo('Sync center');
    await context.setOffline(false);
    await page.getByRole('button', { name: 'Review' }).click({ timeout: 60_000 });
    const review = dialog(page, 'Review conflicting change');
    await review.getByRole('button', { name: 'Decide later' }).click();
    await expect(review).toBeHidden();
    await expect(page.getByRole('heading', { name: /Needs your attention/ })).toContainText('1');

    await shell.goTo('Mortality');
    await expect(row).toContainText('Needs review');
    expect((await serverMortality(api, id))['numberOfDeaths']).toBe(9);
  });

  // DEFECT: the edit form sends every field as changed (mortality-form-dialog.ts calls update with
  // all form values), so a server change to another field is reported as a conflict instead of
  // being merged by mergeConflict().
  test(
    'changes to different fields are merged without asking',
    { tag: '@DEF-003' },
    async ({ freshFarm, farmApi, signInAs, shell, page, context }) => {
      const reason = marker('Merge');
      const { api, id, row } = await setup({ freshFarm, farmApi, signInAs, page }, reason);
      const newReason = marker('Merged reason');
      await editDeathsOffline(page, row, context, null, newReason);
      await api.update(
        'MORTALITY',
        await serverMortality(api, id),
        { numberOfDeaths: 6 },
        MORTALITY_FIELDS,
      );

      await context.setOffline(false);
      await shell.goTo('Sync center');
      await expect(page.getByRole('heading', { name: 'Everything is synced' })).toBeVisible({
        timeout: 20_000,
      });
      await expect(page.getByRole('heading', { name: /Needs your attention/ })).toHaveCount(0);

      await expect
        .poll(async () => (await serverMortality(api, id))['reason'], { timeout: 30_000 })
        .toBe(newReason);
      expect((await serverMortality(api, id))['numberOfDeaths']).toBe(6);
    },
  );

  test('a change the server rejects can be retried or discarded', async ({
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
    const coopId = await api.createCoop({ coopName: 'Doomed Coop', numberOfChickens: 100 });
    await api.createCoop({ coopName: 'Surviving Coop', numberOfChickens: 100 });
    await signInAs(farm.owner, '/expenses');
    await expect(page.getByRole('heading', { name: 'No expenses yet' })).toBeVisible();
    await waitForServiceWorker(page);

    await context.setOffline(true);
    await page.getByRole('button', { name: 'Add expense' }).first().click();
    const form = dialog(page, 'Add expense');
    const note = marker('Doomed expense');
    await choose(page, form, 'Coop', 'Doomed Coop');
    await choose(page, form, 'Expense type', 'Feed Costs');
    await form.getByLabel('Amount').fill('250');
    await form.getByLabel('Notes').fill(note);
    await form.getByRole('button', { name: 'Save expense' }).click();
    await expect(form).toBeHidden();

    await api.remove('COOP', coopId);

    await shell.goTo('Sync center');
    await context.setOffline(false);
    await expect(
      page.getByRole('heading', { name: 'Some changes need your attention' }),
    ).toBeVisible({ timeout: 60_000 });
    const item = page.locator('li.failed');
    await expect(item).toContainText('Coop not found');
    await shot(page, 'sync', 'failed-op');

    await item.getByRole('button', { name: 'Retry' }).click();
    await expect(item).toContainText('Coop not found', { timeout: 30_000 });
    await expect(item.getByRole('button', { name: 'Discard' })).toBeVisible();

    await item.getByRole('button', { name: 'Discard' }).click();
    await dialog(page, 'Discard this change?').getByRole('button', { name: 'Discard' }).click();
    await expect(page.locator('li.failed')).toHaveCount(0);
    await expect(page.getByRole('heading', { name: 'Everything is synced' })).toBeVisible({
      timeout: 60_000,
    });
    await expect(page.getByText('Nothing waiting')).toBeVisible();
    expect((await api.snapshot()).expenses.some((e) => e['additionalInfo'] === note)).toBe(false);
  });
});
