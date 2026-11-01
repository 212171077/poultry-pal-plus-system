import { Page, expect, test } from '@playwright/test';
import { signIn, useOwnFarm, waitForServiceWorker } from './helpers';

/** The mock farm's only coop: 500 layers in the production phase (see e2e/mock-api.mjs). */
const LAYER_COOP = 'Layer House A';

test.beforeEach(async ({ context, baseURL, page }, testInfo) => {
  await useOwnFarm(context, baseURL, testInfo);
  await signIn(page);
});

async function mockRecords<T>(page: Page, type: string, marker = ''): Promise<T[]> {
  const response = await page.request.get(`/__mock/records?type=${type}&marker=${marker}`);
  return (await response.json()) as T[];
}

function coopCard(page: Page, name: string) {
  return page.getByTestId('coop-card').filter({ has: page.getByRole('heading', { name }) });
}

test('a sale recorded offline through Quick Add syncs with the right total', async ({
  page,
  context,
}, testInfo) => {
  test.slow();
  const buyer = `Buyer ${testInfo.project.name} ${Date.now()}`;
  await page.goto('/sync');
  await waitForServiceWorker(page);
  await expect(page.getByRole('heading', { name: 'Everything is synced' })).toBeVisible();

  await context.setOffline(true);
  await page.goto('/dashboard');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  if (testInfo.project.name === 'mobile') {
    await page.getByRole('button', { name: 'Quick add' }).click();
  } else {
    await page.keyboard.press('n');
  }
  await page.getByRole('menuitem', { name: 'Record a sale' }).click();

  const dialog = page.getByRole('dialog', { name: 'Record a sale' });
  await expect(dialog).toBeVisible();
  await dialog.getByLabel('Packaging').click();
  await page.getByRole('option', { name: 'Tray of 30 eggs' }).click();
  await dialog.getByLabel('Number of trays sold').fill('12');
  await dialog.getByLabel('Price per tray').fill('37.5');
  await expect(dialog.getByTestId('sale-total')).toContainText('450.00');
  await dialog.getByLabel('Additional info').fill(buyer);
  await dialog.getByRole('radio', { name: 'Payment pending' }).click();
  await dialog.getByRole('button', { name: 'Save sale' }).click();
  await expect(dialog).toBeHidden();

  const row = page.getByTestId('sale-row').filter({ hasText: buyer });
  await expect(row).toContainText('Payment pending');
  await expect(row).toContainText('Waiting to sync');

  await context.setOffline(false);
  await expect(row).toContainText('Synced', { timeout: 20_000 });
  const [sale] = await mockRecords<{ totalSaleAmount: number; paymentStatus: string }>(
    page,
    'SALE',
    buyer,
  );
  expect(sale.totalSaleAmount).toBe(450);
  expect(sale.paymentStatus).toBe('PENDING');

  await row.getByRole('button', { name: /More actions/ }).click();
  await page.getByRole('menuitem', { name: 'Mark as paid' }).click();
  await expect(row).not.toContainText('Payment pending');
  await expect
    .poll(async () => (await mockRecords<{ paymentStatus: string }>(page, 'SALE', buyer))[0])
    .toMatchObject({ paymentStatus: 'PAID' });
});

test('losses and eggs recorded from a coop card update the flock', async ({ page }, testInfo) => {
  const reason = `Heat stress ${testInfo.project.name} ${Date.now()}`;
  await page.goto('/coops');
  const card = coopCard(page, LAYER_COOP);
  await expect(card.getByTestId('coop-alive')).toHaveText('500');

  await card.getByRole('link', { name: 'Loss' }).click();
  const loss = page.getByRole('dialog', { name: 'Record mortality' });
  await expect(loss.getByRole('combobox', { name: 'Coop' })).toContainText(LAYER_COOP);
  await loss.getByLabel('Number of deaths').fill('30');
  await loss.getByLabel('Reason').fill(reason);
  await loss.getByRole('button', { name: 'Save record' }).click();
  await expect(loss).toBeHidden();
  await expect(page.getByTestId('mortality-row').filter({ hasText: reason })).toHaveCount(1);

  await page.goto('/coops');
  await expect(card.getByTestId('coop-alive')).toHaveText('470');
  // 30 / (500 + 30) = 5.7 %, above the 5 % alert level.
  await expect(card.getByTestId('coop-rate')).toHaveText('5.7%');
  await expect(card.getByTestId('coop-rate')).toHaveClass(/alert/);

  await card.getByRole('link', { name: 'Eggs' }).click();
  const eggs = page.getByRole('dialog', { name: 'Log egg packaging' });
  await eggs.getByLabel('Number of boxes').fill('4');
  await expect(eggs.getByTestId('egg-total')).toContainText('120');
  await eggs.getByLabel('Notes').fill(reason);
  await eggs.getByRole('button', { name: 'Save record' }).click();
  await expect(eggs).toBeHidden();

  await expect
    .poll(async () => (await mockRecords<{ totalEggs: number }>(page, 'EGG_PACKAGING', reason))[0])
    .toMatchObject({ totalEggs: 120 });
  await expect
    .poll(async () => (await mockRecords<{ numberOfDeaths: number }>(page, 'MORTALITY', reason))[0])
    .toMatchObject({ numberOfDeaths: 30 });
});

test('moves a flock to a new coop and starts a new batch', async ({ page }, testInfo) => {
  test.slow();
  const grower = `Grower ${testInfo.project.name} ${Date.now()}`;
  await page.goto('/coops');

  await page.getByRole('button', { name: 'Add coop' }).first().click();
  const add = page.getByRole('dialog', { name: 'Add a coop' });
  await add.getByLabel('Coop name').fill(grower);
  await add.getByRole('combobox', { name: 'Coop type' }).click();
  await page.getByRole('option', { name: 'Layers' }).click();
  await add.getByLabel('Number of chickens').fill('0');
  await add.getByRole('button', { name: 'Add coop' }).click();
  await expect(add).toBeHidden();
  await expect(coopCard(page, grower)).toContainText('Empty');

  // Move the layers into the new, empty coop.
  await coopCard(page, LAYER_COOP)
    .getByRole('button', { name: `More actions for ${LAYER_COOP}` })
    .click();
  await page.getByRole('menuitem', { name: 'Change phase' }).click();
  const phase = page.getByRole('dialog', { name: 'Change growth phase' });
  await phase.getByRole('combobox', { name: 'Where is the flock going?' }).click();
  await page.getByRole('option', { name: `Move to ${grower}` }).click();
  await phase.getByRole('button', { name: 'Change phase' }).click();
  await expect(phase).toBeHidden();

  await expect(coopCard(page, grower).getByTestId('coop-alive')).toHaveText('500');
  await expect(coopCard(page, LAYER_COOP).getByTestId('coop-alive')).toHaveText('0');
  await expect
    .poll(async () => {
      const coops = await mockRecords<{ coopName: string; numberOfChickens: number }>(page, 'COOP');
      return Object.fromEntries(coops.map((coop) => [coop.coopName, coop.numberOfChickens]));
    })
    .toMatchObject({ [grower]: 500, [LAYER_COOP]: 0 });

  // Restock the original coop: the confirmation comes first, then the batch form.
  await coopCard(page, LAYER_COOP)
    .getByRole('button', { name: `More actions for ${LAYER_COOP}` })
    .click();
  await page.getByRole('menuitem', { name: 'Start new batch' }).click();
  const confirm = page.getByRole('dialog', { name: 'Confirm New Batch Addition' });
  await confirm.getByRole('button', { name: 'Continue' }).click();
  const batch = page.getByRole('dialog', { name: 'Start a new batch' });
  await batch.getByLabel('Number of chickens').fill('300');
  await batch.getByRole('button', { name: 'Start batch' }).click();
  await expect(batch).toBeHidden();

  await expect(coopCard(page, LAYER_COOP).getByTestId('coop-alive')).toHaveText('300');
  await expect
    .poll(async () => {
      const coops = await mockRecords<{
        coopName: string;
        growthPhase: string;
        numberOfChickens: number;
      }>(page, 'COOP', LAYER_COOP);
      return coops[0];
    })
    .toMatchObject({ numberOfChickens: 300, growthPhase: 'BROODING_PHASE' });
});
