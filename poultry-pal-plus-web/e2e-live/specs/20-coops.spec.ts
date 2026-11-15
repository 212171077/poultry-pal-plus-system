import { expect, test } from '../fixtures';
import { choose, confirmDelete, coopCard, dialog, marker, rowAction } from '../pages/records';

test.describe('coops: read-only views', () => {
  test('seeded coops are listed with live birds, status and sync state', async ({
    seededFarm,
    signInAs,
    page,
    shot,
  }) => {
    await signInAs(seededFarm.owner, '/coops');
    await expect(page.getByRole('heading', { name: 'Coops & batches', level: 1 })).toBeVisible();
    const layers = coopCard(page, seededFarm.data.layers.name);
    const broilers = coopCard(page, seededFarm.data.broilers.name);
    await expect(layers).toBeVisible();
    await expect(broilers).toBeVisible();
    // 500 layers - 5 deaths, 1000 broilers - 12 deaths (seed data).
    await expect(layers.getByTestId('coop-alive')).toHaveText('495');
    await expect(broilers.getByTestId('coop-alive')).toHaveText('988');
    await expect(layers).toContainText('Layers');
    await expect(broilers).toContainText('Broiler');
    await expect(page.getByTestId('coops-live-birds')).toHaveText('1,483');
    await expect(layers.getByRole('img', { name: 'Layers coop' })).toBeVisible();
    await expect(broilers.getByRole('img', { name: /Broilers? coop/ })).toBeVisible();
    await expect(layers.getByRole('link')).toHaveCount(0);
    await shot(page, 'coops', 'cards');
  });

  test('the table layout shows the same coops and the choice is remembered', async ({
    seededFarm,
    signInAs,
    page,
    shot,
  }) => {
    await signInAs(seededFarm.owner, '/coops');
    await page.getByRole('radio', { name: 'Table' }).click();
    await expect(page.getByTestId('coop-row')).toHaveCount(2);
    await shot(page, 'coops', 'table');
    await page.reload();
    await expect(page.getByTestId('coop-row')).toHaveCount(2);
    await page.getByRole('radio', { name: 'Cards' }).click();
    await expect(page.getByTestId('coop-card')).toHaveCount(2);
  });

  test('a farm without coops shows the empty state with an add action', async ({
    freshFarm,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    await signInAs(farm.owner, '/coops');
    await expect(page.getByRole('heading', { name: 'No coops yet' })).toBeVisible();
    await shot(page, 'coops', 'empty-state');
  });

  test('a worker sees only assigned coops and no manager actions', async ({
    seededFarm,
    signInAs,
    page,
    shot,
  }) => {
    await signInAs(seededFarm.worker, '/coops');
    await expect(coopCard(page, seededFarm.data.layers.name)).toBeVisible();
    await expect(page.getByTestId('coop-card')).toHaveCount(1);
    await expect(page.getByRole('button', { name: 'Add coop' })).toHaveCount(0);
    await expect(page.getByRole('link', { name: 'Archived batches' })).toHaveCount(0);
    await coopCard(page, seededFarm.data.layers.name)
      .getByRole('button', { name: /More actions/ })
      .click();
    await expect(page.getByRole('menuitem', { name: 'Edit' })).toHaveCount(0);
    await expect(page.getByRole('menuitem', { name: 'Delete' })).toHaveCount(0);
    await shot(page, 'coops', 'worker-menu');
  });
});

test.describe('coops: create, edit, delete', () => {
  test('adding a coop validates input, saves locally and syncs to the backend', async ({
    freshFarm,
    farmApi,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    await signInAs(farm.owner, '/coops');
    const name = marker('Grower');

    await page.getByRole('button', { name: 'Add coop' }).first().click();
    const add = dialog(page, 'Add a coop');
    await shot(page, 'coops', 'add-dialog');
    await add.getByRole('button', { name: 'Add coop' }).click();
    await expect(add.getByText('Enter a name for the coop')).toBeVisible();
    await shot(page, 'coops', 'add-dialog-validation');

    await add.getByLabel('Coop name').fill(name);
    await choose(page, add, 'Coop type', 'Broiler');
    await add.getByLabel('Number of chickens').fill('250');
    await add.getByRole('button', { name: 'Add coop' }).click();
    await expect(add).toBeHidden();

    const card = coopCard(page, name);
    await expect(card).toBeVisible();
    await expect(card.getByTestId('coop-alive')).toHaveText('250');
    await expect(card).toContainText('Synced', { timeout: 30_000 });
    const saved = await api.eventually(
      (s) => s.coops.find((c) => c['coopName'] === name),
      `coop ${name}`,
    );
    expect(saved['numberOfChickens']).toBe(250);
    expect(saved['coopType']).toBe('BROILER');
  });

  test('a negative number of chickens is rejected', async ({ freshFarm, signInAs, page }) => {
    const farm = await freshFarm();
    await signInAs(farm.owner, '/coops');
    await page.getByRole('button', { name: 'Add coop' }).first().click();
    const add = dialog(page, 'Add a coop');
    await add.getByLabel('Coop name').fill('Negative flock');
    await add.getByLabel('Number of chickens').fill('-5');
    await add.getByRole('button', { name: 'Add coop' }).click();
    await expect(add.getByText('Enter 0 or more chickens')).toBeVisible();
    await expect(add).toBeVisible();
  });

  test('editing a coop updates the list and the backend', async ({
    freshFarm,
    farmApi,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    const original = marker('Old name');
    const renamed = marker('New name');
    await api.createCoop({ coopName: original, numberOfChickens: 120 });
    await signInAs(farm.owner, '/coops');

    await coopCard(page, original)
      .getByRole('button', { name: `More actions for ${original}` })
      .click();
    await page.getByRole('menuitem', { name: 'Edit' }).click();
    const edit = dialog(page, 'Edit coop');
    await expect(edit.getByLabel('Coop name')).toHaveValue(original);
    await shot(page, 'coops', 'edit-dialog');
    await edit.getByLabel('Coop name').fill(renamed);
    await edit.getByLabel('Number of chickens').fill('140');
    await edit.getByRole('button', { name: 'Save changes' }).click();
    await expect(edit).toBeHidden();
    await expect(coopCard(page, renamed)).toBeVisible();
    await expect(coopCard(page, original)).toHaveCount(0);

    const saved = await api.eventually(
      (s) => s.coops.find((c) => c['coopName'] === renamed),
      `renamed coop ${renamed}`,
    );
    expect(saved['numberOfChickens']).toBe(140);
  });

  test('deleting a coop asks for confirmation and removes it from the backend', async ({
    freshFarm,
    farmApi,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    const name = marker('Doomed');
    await api.createCoop({ coopName: name });
    await signInAs(farm.owner, '/coops');

    await coopCard(page, name)
      .getByRole('button', { name: /More actions/ })
      .click();
    await page.getByRole('menuitem', { name: 'Delete' }).click();
    await shot(page, 'coops', 'delete-confirmation');
    await dialog(page, `Delete ${name}?`).getByRole('button', { name: 'Cancel' }).click();
    await expect(coopCard(page, name)).toBeVisible();

    await coopCard(page, name)
      .getByRole('button', { name: /More actions/ })
      .click();
    await page.getByRole('menuitem', { name: 'Delete' }).click();
    await confirmDelete(page, `Delete ${name}?`);
    await expect(coopCard(page, name)).toHaveCount(0);
    await expect
      .poll(async () => (await api.snapshot()).coops.some((c) => c['coopName'] === name))
      .toBe(false);
  });
});

test.describe('coops: phases and batches', () => {
  test('changing the growth phase keeps the flock and syncs the new phase', async ({
    freshFarm,
    farmApi,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    const name = marker('Phase');
    await api.createCoop({
      coopName: name,
      coopType: 'BROILER',
      growthPhase: 'BROODING_PHASE',
      numberOfChickens: 200,
    });
    await signInAs(farm.owner, '/coops');

    await rowAction(coopCard(page, name), page, 'Change phase');
    const phase = dialog(page, 'Change growth phase');
    await shot(page, 'coops', 'phase-dialog');
    await choose(page, phase, 'New phase', /Growing/);
    await phase.getByRole('button', { name: 'Change phase' }).click();
    await expect(phase).toBeHidden();

    await expect(coopCard(page, name)).toContainText('Growing');
    const saved = await api.eventually(
      (s) =>
        s.coops.find((c) => c['coopName'] === name && c['growthPhase'] === 'GROWING_REARING_PHASE'),
      'coop in growing phase',
    );
    expect(saved['numberOfChickens']).toBe(200);
  });

  test('moving the flock to another coop transfers the chickens', async ({
    freshFarm,
    farmApi,
    signInAs,
    page,
  }) => {
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    const from = marker('From');
    const to = marker('To');
    await api.createCoop({ coopName: from, numberOfChickens: 300 });
    await api.createCoop({ coopName: to, numberOfChickens: 0 });
    await signInAs(farm.owner, '/coops');

    await rowAction(coopCard(page, from), page, 'Change phase');
    const phase = dialog(page, 'Change growth phase');
    await choose(page, phase, 'Where is the flock going?', `Move to ${to}`);
    await phase.getByRole('button', { name: 'Change phase' }).click();
    await expect(phase).toBeHidden();

    await expect(coopCard(page, to).getByTestId('coop-alive')).toHaveText('300');
    await expect(coopCard(page, from).getByTestId('coop-alive')).toHaveText('0');
    await expect
      .poll(async () => {
        const coops = (await api.snapshot()).coops;
        return Object.fromEntries(coops.map((c) => [c['coopName'], c['numberOfChickens']]));
      })
      .toMatchObject({ [to]: 300, [from]: 0 });
  });

  test('starting a new batch archives the previous one', async ({
    freshFarm,
    farmApi,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    const name = marker('Batch');
    const coopId = await api.createCoop({ coopName: name, numberOfChickens: 100 });
    await api.addSale(coopId, { eggPackaging: 'TRAY_30', quantitySold: 4, pricePerUnit: 50 });
    await signInAs(farm.owner, '/coops');

    await rowAction(coopCard(page, name), page, 'Start new batch');
    const confirm = dialog(page, 'Confirm New Batch Addition');
    await shot(page, 'coops', 'new-batch-confirmation');
    await confirm.getByRole('button', { name: 'Continue' }).click();
    const batch = dialog(page, 'Start a new batch');
    await batch.getByLabel('Number of chickens').fill('300');
    await batch.getByRole('button', { name: 'Start batch' }).click();
    await expect(batch).toBeHidden();
    await expect(coopCard(page, name).getByTestId('coop-alive')).toHaveText('300');
    await api.eventually(
      (s) => s.coops.find((c) => c['coopName'] === name && c['numberOfChickens'] === 300),
      'restocked coop',
    );

    await page.getByRole('link', { name: 'Archived batches' }).click();
    await expect(page).toHaveURL(/\/coops\/archive$/);
    const archived = page.getByTestId('archived-batch').filter({ hasText: name });
    await expect(archived).toBeVisible({ timeout: 30_000 });
    await expect(archived).toContainText('100 birds');
    await shot(page, 'coops-archive', 'one-batch');
  });

  test('the archive is empty for a farm that never started a new batch', async ({
    freshFarm,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    await signInAs(farm.owner, '/coops/archive');
    await expect(page.getByRole('heading', { name: 'No archived batches' })).toBeVisible();
    await shot(page, 'coops-archive', 'empty-state');
  });
});
