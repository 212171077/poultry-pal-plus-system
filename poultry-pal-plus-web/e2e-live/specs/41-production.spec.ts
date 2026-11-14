import { Page } from '@playwright/test';
import { expect, test } from '../fixtures';
import { newApi, signInApi } from '../infra/api';

const toast = (page: Page, text: string | RegExp) =>
  page.locator('mat-snack-bar-container').filter({ hasText: text });

const TABS: [label: string, path: RegExp, heading: string][] = [
  ['Dashboard', /\/production\/dashboard/, 'Production dashboard'],
  ['Batches', /\/production\/batches/, 'Incubation batches'],
  ['Plan a batch', /\/production\/schedule/, 'Plan a batch'],
  ['Plans', /\/production\/plans/, 'Production plans'],
  ['Chicken houses', /\/production\/placements/, 'Chicken houses'],
  ['Hatch results', /\/production\/results/, 'Hatch results'],
  ['Settings', /\/production\/settings/, 'Production settings'],
];

/** M/D/YYYY, the format the date picker input accepts in the en-US test browser. */
function pickerDate(daysFromToday: number): string {
  const d = new Date(Date.now() + daysFromToday * 86_400_000);
  return `${d.getMonth() + 1}/${d.getDate()}/${d.getFullYear()}`;
}

async function fillDate(page: Page, label: string, daysFromToday: number): Promise<void> {
  const input = page.getByLabel(label, { exact: true });
  await input.fill(pickerDate(daysFromToday));
  await input.blur();
}

test.describe('production', () => {
  test('a production manager gets the production area and every section opens', async ({
    sharedFarm,
    signInAs,
    shell,
    page,
    shot,
  }) => {
    await signInAs(sharedFarm.productionManager);
    expect(await shell.navLabels()).toContain('Production');
    expect(await shell.navLabels()).not.toContain('Team');

    await shell.goTo('Production');
    await expect(page).toHaveURL(/\/production\/dashboard/);
    const sections = page.getByRole('navigation', { name: 'Production sections' });
    for (const [label, path, heading] of TABS) {
      await sections.getByRole('link', { name: label, exact: true }).click();
      await expect(page, label).toHaveURL(path);
      await expect(page.getByRole('heading', { level: 1 }).first(), label).toContainText(heading);
      await expect(page.getByRole('alert'), `${label} shows no error`).toHaveCount(0);
      await shot(page, 'production', label.toLowerCase().replace(/\s+/g, '-'));
    }
  });

  test('empty production pages explain what to do next', async ({
    freshFarm,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    await signInAs(farm.owner, '/production/batches');
    await expect(page.getByRole('heading', { name: 'No batches yet' })).toBeVisible();
    await shot(page, 'production', 'batches-empty');
    await page.goto('/production/results');
    await expect(page.getByRole('heading', { name: 'No hatch results yet' })).toBeVisible();
    await page.goto('/production/plans');
    await expect(page.getByRole('heading', { name: 'No saved plans' })).toBeVisible();
    await page.goto('/production/dashboard');
    await expect(page.getByRole('region', { name: 'Totals' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Nothing scheduled' })).toBeVisible();
    await shot(page, 'production', 'dashboard-empty');
  });

  test('settings and equipment capacity are validated and saved', async ({
    freshFarm,
    farmApi,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    // Candidate defect: the first visit loads settings and equipment in parallel, and the lazy
    // initialisation on a brand-new farm can leave the equipment list empty. Initialise first.
    expect((await api.api.get('/api/v1/production/equipment')).status()).toBe(200);
    await signInAs(farm.owner, '/production/settings');
    const rate = page.getByLabel('Expected hatch rate (%)');
    await expect(rate).toBeVisible();
    await rate.fill('80');
    await page.getByRole('button', { name: 'Save settings' }).click();
    await expect(toast(page, 'Production settings saved.')).toBeVisible();
    const saved = await api.api.get('/api/v1/production/settings');
    expect(saved.status()).toBe(200);
    expect(JSON.stringify(await saved.json())).toContain('"expectedHatchRate":0.8');

    const equipment = page.locator('.equipment').first();
    await expect(equipment).toBeVisible({ timeout: 30_000 });
    const name = (await equipment.locator('strong').innerText()).trim();
    await equipment.getByLabel('Capacity').fill('0');
    await equipment.getByRole('button', { name: 'Save' }).click();
    await expect(page.getByRole('alert')).toContainText('Capacity must be a whole number');
    await shot(page, 'production', 'settings-validation');

    await equipment.getByLabel('Capacity').fill('1234');
    await equipment.getByRole('button', { name: 'Save' }).click();
    await expect(toast(page, `${name} updated.`)).toBeVisible();
    await page.reload();
    await expect(page.locator('.equipment').first().getByLabel('Capacity')).toHaveValue('1234');
  });

  test('an incubation batch goes from planned to a recorded hatch result', async ({
    freshFarm,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    await signInAs(farm.owner, '/production/batches');
    await page.getByRole('button', { name: 'New batch' }).click();
    const form = page.locator('form');
    await form.getByRole('button', { name: 'Create batch' }).click();
    await expect(form.getByLabel('Eggs set')).toHaveAttribute('aria-invalid', 'true');
    await shot(page, 'production', 'batch-validation');

    await form.getByRole('combobox', { name: 'Incubator' }).click();
    await page.getByRole('option').first().click();
    await form.getByLabel('Eggs set').fill('200');
    await fillDate(page, 'Start date', 0);
    const reference = await form.getByLabel('Reference').inputValue();
    expect(reference).toMatch(/^[A-Z]{3}\d{2}-200$/);
    await form.getByRole('button', { name: 'Create batch' }).click();
    await expect(toast(page, 'Batch created.')).toBeVisible();

    const batch = page
      .locator('section')
      .filter({ has: page.getByRole('heading', { name: reference }) });
    await expect(batch).toContainText('Planned');
    await expect(batch).toContainText('200 eggs');
    await shot(page, 'production', 'batch-planned');

    await batch.getByRole('button', { name: 'Start incubation' }).click();
    await expect(batch).toContainText('Incubating');

    await batch.getByRole('combobox', { name: 'Hatcher' }).click();
    await page.getByRole('option').first().click();
    await batch.getByRole('button', { name: 'Reserve hatcher' }).click();
    await expect(batch).toContainText('eggs reserved for hatching');
    await expect(batch.getByRole('button', { name: 'Transfer now' })).toBeVisible();
    await shot(page, 'production', 'batch-reserved');

    await batch.getByRole('button', { name: 'Transfer now' }).click();
    await expect(batch.getByLabel('Hatched chicks')).toBeVisible();
    await batch.getByLabel('Hatched chicks').fill('150');
    await expect(batch.getByLabel('Unhatched eggs')).toHaveValue('50');
    await batch.getByLabel('Weak chicks').fill('5');
    await fillDate(page, 'Result date', 0);
    await batch.getByRole('button', { name: 'Record result' }).click();
    await expect(toast(page, 'Hatch result saved.')).toBeVisible();
    await shot(page, 'production', 'batch-result-saved');

    await page.goto('/production/results');
    await expect(page.getByRole('heading', { name: 'Summary' })).toBeVisible();
    await expect(page.getByText(/150 chicks from\s+200 eggs/)).toBeVisible();
    await expect(page.getByText(/hatch rate of 75/)).toBeVisible();
    await shot(page, 'production', 'hatch-results');
  });

  // DEFECT: the reference field's (input) handler runs after the form control updates, so the
  // first keystroke is overwritten by the generated MONDD-eggs reference and typed text is mangled.
  test(
    'a custom batch reference is kept as typed',
    { tag: '@DEF-005' },
    async ({ freshFarm, signInAs, page }) => {
      test.setTimeout(30_000);
      const farm = await freshFarm();
      await signInAs(farm.owner, '/production/batches');
      await page.getByRole('button', { name: 'New batch' }).click();
      const reference = page.locator('form').getByLabel('Reference');
      await reference.click();
      await reference.pressSequentially('MYBATCH1', { delay: 30 });
      await expect(reference).toHaveValue('MYBATCH1', { timeout: 3000 });
    },
  );

  test('a planned batch can be cancelled', async ({ freshFarm, signInAs, page }) => {
    const farm = await freshFarm();
    await signInAs(farm.owner, '/production/batches');
    await page.getByRole('button', { name: 'New batch' }).click();
    const form = page.locator('form');
    await form.getByRole('combobox', { name: 'Incubator' }).click();
    await page.getByRole('option').first().click();
    await form.getByLabel('Eggs set').fill('100');
    await fillDate(page, 'Start date', 1);
    const reference = await form.getByLabel('Reference').inputValue();
    await form.getByRole('button', { name: 'Create batch' }).click();
    const batch = page
      .locator('section')
      .filter({ has: page.getByRole('heading', { name: reference }) });
    await expect(batch).toBeVisible();
    await batch.getByRole('button', { name: 'Cancel batch' }).click();
    await expect(batch).toContainText('Cancelled');
    await expect(batch.getByRole('button', { name: 'Start incubation' })).toHaveCount(0);
  });

  test('chicks are placed in a house and removals reduce the count', async ({
    freshFarm,
    farmApi,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    const created = await api.api.post('/api/v1/production/equipment', {
      data: { type: 'CHICKEN_HOUSE', name: 'E2E House', capacity: 500 },
    });
    expect(created.status(), await created.text()).toBeLessThan(300);
    await signInAs(farm.owner, '/production/placements');
    const house = page
      .locator('section')
      .filter({ has: page.getByRole('heading', { level: 2 }) })
      .first();
    await expect(house).toContainText('free');
    await shot(page, 'production', 'placements-before');

    await page.getByLabel('Chicks', { exact: true }).fill('100');
    await fillDate(page, 'Placement date', 0);
    await page.getByRole('button', { name: 'Place chicks' }).click();

    const placement = page
      .locator('section')
      .filter({ has: page.getByRole('button', { name: 'Record' }) });
    await expect(placement).toContainText('100 of 100 remain');
    await placement.getByLabel('Birds', { exact: true }).fill('7');
    await fillDate(page, 'Date', 0);
    await placement.getByLabel('Type').selectOption({ index: 0 });
    await placement.getByRole('button', { name: 'Record' }).click();
    await expect(placement).toContainText('93 of 100 remain');
    await shot(page, 'production', 'placements-after');
  });

  test('plan a batch finds start dates and nothing is reserved', async ({
    freshFarm,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    await signInAs(farm.owner, '/production/schedule');
    await page.getByRole('button', { name: 'Find start dates' }).click();
    await expect(page.getByRole('alert')).toContainText('Enter the number of eggs');

    await page.getByLabel('Eggs to set').fill('300');
    await fillDate(page, 'Earliest start', 1);
    await fillDate(page, 'Latest start', 7);
    await page.getByRole('button', { name: 'Find start dates' }).click();
    await expect(page.getByRole('heading', { name: 'Result' })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Each start date' })).toBeVisible();
    await expect(page.getByRole('row')).not.toHaveCount(1);
    await shot(page, 'production', 'schedule-result');
  });

  test('a production plan can be calculated, saved as a draft and cancelled', async ({
    freshFarm,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    await signInAs(farm.owner, '/production/plans');
    await page.getByRole('button', { name: 'Calculate' }).click();
    await expect(page.getByRole('alert')).toContainText('Enter the date you want birds ready');

    await fillDate(page, 'Birds ready on', 90);
    await page.getByLabel('Birds needed').fill('200');
    await page.getByLabel('Name (optional)').fill('E2E plan');
    await page.getByRole('button', { name: 'Calculate' }).click();
    await expect(
      page.getByRole('heading', { name: /This plan (fits|does not fit)/ }),
    ).toBeVisible();
    await shot(page, 'production', 'plan-calculated');

    await page.getByRole('button', { name: 'Save as draft' }).click();
    const plan = page
      .locator('section')
      .filter({ has: page.getByRole('heading', { name: /E2E plan/ }) });
    await expect(plan).toContainText('Draft');
    await plan.getByRole('button', { name: 'Cancel plan' }).click();
    await expect(plan).toContainText('Cancelled');
  });

  test('production data is unavailable to a user without production access', async ({
    sharedFarm,
    signInAs,
    page,
  }) => {
    await signInAs(sharedFarm.worker);
    await page.goto('/production/dashboard');
    await expect(page).toHaveURL(/\/dashboard$/);
    await expect(page.getByRole('heading', { name: 'Production dashboard' })).toHaveCount(0);
    const api = await newApi();
    await signInApi(api, sharedFarm.worker);
    const response = await api.get('/api/v1/production/snapshot');
    expect(response.status()).toBe(403);
    await api.dispose();
  });
});
