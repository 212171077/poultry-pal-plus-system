import { expect, test } from '../fixtures';
import { newApi } from '../infra/api';
import { choose, marker } from '../pages/records';

const toast = (page: import('@playwright/test').Page, text: string | RegExp) =>
  page.locator('mat-snack-bar-container').filter({ hasText: text });

interface Member {
  id: string;
  email: string;
  active?: boolean;
  roles?: string[];
  permissions?: string[];
  userCoopIds?: string[];
}

test.describe('team', () => {
  async function team(api: import('../infra/farm-api').FarmApi): Promise<Member[]> {
    const response = await api.api.get('/api/v1/team');
    expect(response.status()).toBe(200);
    return ((await response.json()) as { data: Member[] }).data;
  }

  const card = (page: import('@playwright/test').Page, name: string) =>
    page.getByRole('listitem').filter({ has: page.getByRole('heading', { name }) });

  test('owner sees the team with roles and contact details', async ({
    sharedFarm,
    signInAs,
    page,
    shot,
  }) => {
    await signInAs(sharedFarm.owner, '/team');
    await expect(page.getByRole('heading', { name: 'Team', level: 1 })).toBeVisible();
    const members = page.getByRole('list', { name: 'Farm team members' });
    await expect(
      members.getByRole('listitem').filter({ hasText: sharedFarm.manager.email }),
    ).toContainText('Farm manager');
    await expect(
      members.getByRole('listitem').filter({ hasText: sharedFarm.worker.email }),
    ).toContainText('Farm worker');
    await shot(page, 'team', 'owner-view');
  });

  test('adding a member validates the form, creates a worker who can sign in, and rejects duplicates', async ({
    diagnostics,
    freshFarm,
    farmApi,
    signInAs,
    page,
    shot,
  }) => {
    diagnostics.expect({ status: 409 });
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    await signInAs(farm.owner, '/team');

    await page.getByRole('button', { name: 'Add team member' }).click();
    const form = page.getByRole('form').or(page.locator('form'));
    await form.getByRole('button', { name: 'Add member' }).click();
    await expect(form.getByText('Enter a first name.')).toBeVisible();
    await expect(form.getByText('Enter a surname.')).toBeVisible();
    await expect(form.getByText('Enter a phone number.')).toBeVisible();
    await form.getByLabel('Email').fill('not-an-email');
    await form.getByLabel('Phone number').focus();
    await expect(form.getByText('Enter a valid email address.')).toBeVisible();
    await shot(page, 'team', 'add-validation');

    const unique = marker('hand')
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '');
    const email = `${unique}@example.com`;
    const phone = `0841${Date.now().toString().slice(-6)}`;
    await form.getByLabel('First name').fill('Hannah');
    await form.getByLabel('Surname').fill('Helper');
    await form.getByLabel('Email').fill(email);
    await form.getByLabel('Phone number').fill(phone);
    await form.getByRole('button', { name: 'Add member' }).click();
    await expect(toast(page, 'Team member added')).toBeVisible();

    const added = card(page, 'Hannah Helper');
    await expect(added).toContainText(email);
    await expect(added).toContainText('Farm worker');
    await shot(page, 'team', 'member-added');
    const created = (await team(api)).find((m) => m.email === email);
    expect(created, 'member on the backend').toBeTruthy();

    // The initial password is the phone number.
    const fresh = await newApi();
    const signIn = await fresh.post('/api/v1/auth/signin', {
      data: { username: email, password: phone },
    });
    expect(signIn.status()).toBe(200);
    await fresh.dispose();

    await page.getByRole('button', { name: 'Add team member' }).click();
    await form.getByLabel('First name').fill('Hannah');
    await form.getByLabel('Surname').fill('Again');
    await form.getByLabel('Email').fill(email);
    await form.getByLabel('Phone number').fill('0845550000');
    await form.getByRole('button', { name: 'Add member' }).click();
    await expect(page.locator('mat-snack-bar-container').last()).not.toContainText(
      'Team member added',
    );
    await expect(form).toBeVisible();
    expect((await team(api)).filter((m) => m.email === email)).toHaveLength(1);
  });

  test('the owner can promote a worker to manager and back', async ({
    freshFarm,
    farmApi,
    signInAs,
    page,
  }) => {
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    await signInAs(farm.owner, '/team');
    const worker = card(page, new RegExp(farm.worker.name));
    await choose(page, worker, `Role for ${farm.worker.name}`, 'Farm manager');
    await expect(toast(page, 'Team role updated.')).toBeVisible();
    await expect(worker).toContainText('Farm manager');
    expect((await team(api)).find((m) => m.email === farm.worker.email)?.roles).toContain(
      'ROLE_FARM_MANAGER',
    );

    await choose(page, worker, `Role for ${farm.worker.name}`, 'Farm worker');
    await expect(worker).toContainText('Farm worker');
    expect((await team(api)).find((m) => m.email === farm.worker.email)?.roles).not.toContain(
      'ROLE_FARM_MANAGER',
    );
  });

  test('a manager manages workers but cannot make managers or grant production access', async ({
    sharedFarm,
    signInAs,
    page,
    shot,
  }) => {
    await signInAs(sharedFarm.manager, '/team');
    const worker = card(page, new RegExp(sharedFarm.worker.name));
    await expect(worker).toBeVisible();
    await expect(page.getByRole('button', { name: 'Add team member' })).toBeVisible();
    await expect(page.getByRole('button', { name: /production access/ })).toHaveCount(0);

    await worker.getByRole('combobox', { name: `Role for ${sharedFarm.worker.name}` }).click();
    await expect(page.getByRole('option', { name: 'Farm worker' })).toBeVisible();
    await expect(page.getByRole('option', { name: 'Farm manager' })).toHaveCount(0);
    await shot(page, 'team', 'manager-role-options');
    await page.keyboard.press('Escape');
  });

  test('assigning coops limits what the worker sees', async ({
    freshFarm,
    farmApi,
    signInAs,
    page,
    browser,
  }) => {
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    const first = await api.createCoop({ coopName: 'Assigned Coop', numberOfChickens: 50 });
    await api.createCoop({ coopName: 'Hidden Coop', numberOfChickens: 50 });
    await signInAs(farm.owner, '/team');
    await expect(page.getByRole('listitem').first()).toBeVisible();

    const worker = card(page, new RegExp(farm.worker.name));
    await worker.getByRole('combobox', { name: `Assigned coops for ${farm.worker.name}` }).click();
    await page.getByRole('option', { name: 'Assigned Coop' }).click();
    await page.keyboard.press('Escape');
    await expect(toast(page, 'Coop assignment updated.')).toBeVisible();
    expect((await team(api)).find((m) => m.email === farm.worker.email)?.userCoopIds).toEqual([
      first,
    ]);

    const workerPage = await browser.newPage({ viewport: page.viewportSize() ?? undefined });
    const { LoginPage } = await import('../pages/login.page');
    await new LoginPage(workerPage).signInAndWait(farm.worker, '/coops');
    await expect(workerPage.getByTestId('coop-card')).toHaveCount(1);
    await expect(workerPage.getByTestId('coop-card')).toContainText('Assigned Coop');
    await workerPage.close();
  });

  test('deactivating a member blocks sign in until they are activated again', async ({
    freshFarm,
    farmApi,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    await farmApi(farm.owner);
    await signInAs(farm.owner, '/team');
    const worker = card(page, new RegExp(farm.worker.name));

    await worker.getByRole('button', { name: 'Deactivate' }).click();
    await expect(toast(page, 'Team member deactivated.')).toBeVisible();
    await expect(worker).toContainText('Inactive');
    await shot(page, 'team', 'member-inactive');

    const attempt = await newApi();
    const blocked = await attempt.post('/api/v1/auth/signin', {
      data: { username: farm.worker.email, password: farm.worker.password },
    });
    expect(blocked.status(), 'deactivated sign in').toBeGreaterThanOrEqual(400);

    await worker.getByRole('button', { name: 'Activate' }).click();
    await expect(toast(page, 'Team member activated.')).toBeVisible();
    await expect(worker).not.toContainText('Inactive');
    const allowed = await attempt.post('/api/v1/auth/signin', {
      data: { username: farm.worker.email, password: farm.worker.password },
    });
    expect(allowed.status()).toBe(200);
    await attempt.dispose();
  });

  test('the owner grants and revokes production access', async ({
    freshFarm,
    farmApi,
    signInAs,
    page,
  }) => {
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    await signInAs(farm.owner, '/team');
    const member = card(page, new RegExp(farm.productionManager.name));

    await member.getByRole('button', { name: 'Revoke production access' }).click();
    await expect(toast(page, 'Production access revoked.')).toBeVisible();
    expect(
      (await team(api)).find((m) => m.email === farm.productionManager.email)?.permissions ?? [],
    ).not.toContain('PRODUCTION_MANAGE');

    await member.getByRole('button', { name: 'Grant production access' }).click();
    await expect(toast(page, 'Production access granted.')).toBeVisible();
    expect(
      (await team(api)).find((m) => m.email === farm.productionManager.email)?.permissions,
    ).toContain('PRODUCTION_MANAGE');
  });

  test('removing a member asks first and revokes their access', async ({
    freshFarm,
    farmApi,
    signInAs,
    page,
  }) => {
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    await signInAs(farm.owner, '/team');
    const worker = card(page, new RegExp(farm.worker.name));

    await worker.getByRole('button', { name: /^Remove / }).click();
    await page
      .getByRole('dialog', { name: 'Remove team member?' })
      .getByRole('button', { name: 'Cancel' })
      .click();
    await expect(worker).toBeVisible();
    expect((await team(api)).some((m) => m.email === farm.worker.email)).toBe(true);

    await worker.getByRole('button', { name: /^Remove / }).click();
    await page
      .getByRole('dialog', { name: 'Remove team member?' })
      .getByRole('button', { name: 'Remove' })
      .click();
    await expect(toast(page, 'Team member removed.')).toBeVisible();
    expect((await team(api)).some((m) => m.email === farm.worker.email)).toBe(false);

    const attempt = await newApi();
    const response = await attempt.post('/api/v1/auth/signin', {
      data: { username: farm.worker.email, password: farm.worker.password },
    });
    expect(response.status(), 'removed member sign in').toBeGreaterThanOrEqual(400);
    await attempt.dispose();
  });
  // DEFECT: refreshTeam() only bulkPut()s the response into the local users table and never
  // deletes members that are no longer returned, so a removed member stays on the page.
  test(
    'a removed member disappears from the team list',
    { tag: '@DEF-004' },
    async ({ freshFarm, signInAs, page }) => {
      const farm = await freshFarm();
      await signInAs(farm.owner, '/team');
      const worker = card(page, new RegExp(farm.worker.name));
      await worker.getByRole('button', { name: /^Remove / }).click();
      await page
        .getByRole('dialog', { name: 'Remove team member?' })
        .getByRole('button', { name: 'Remove' })
        .click();
      await expect(toast(page, 'Team member removed.')).toBeVisible();
      await expect(worker).toHaveCount(0, { timeout: 5_000 });
    },
  );
});
