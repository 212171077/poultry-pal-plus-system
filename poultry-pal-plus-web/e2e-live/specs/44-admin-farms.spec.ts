import { expect, test } from '../fixtures';
import { dialog } from '../pages/records';

test.describe('admin registered farms', () => {
  test.beforeEach(({ diagnostics }) => {
    // The system admin has no farm, so sync bootstrap answers 403 (candidate defect).
    diagnostics.expect({ status: 403, match: /sync\/bootstrap/ });
  });

  test('admin disables and re-grants a farm user, who is blocked meanwhile', async ({
    admin,
    freshFarm,
    signInAs,
    shell,
    page,
    browser,
  }) => {
    const farm = await freshFarm();
    await signInAs(admin, '/admin/farms');
    expect(await shell.navLabels()).toContain('Farms');
    await page.getByLabel('Search by farm name').fill(farm.name);
    await page.getByRole('button', { name: 'Search' }).click();

    const card = page.getByRole('listitem').filter({ hasText: farm.worker.email }).first();
    await expect(card).toBeVisible();
    await expect(card.getByText('Active').first()).toBeVisible();

    await page.getByRole('button', { name: `Disable access for ${farm.worker.name}` }).click();
    await dialog(page).getByRole('button', { name: 'Disable access' }).click();
    await expect(
      page.getByRole('button', { name: `Grant access to ${farm.worker.name}` }),
    ).toBeVisible();
    await expect(card.getByText('Disabled')).toBeVisible();

    const blocked = await browser.newContext();
    const response = await blocked.request.post('/api/v1/auth/signin', {
      data: { email: farm.worker.email, password: farm.worker.password },
    });
    expect(response.ok()).toBeFalsy();
    await blocked.close();

    await page.getByRole('button', { name: `Grant access to ${farm.worker.name}` }).click();
    await dialog(page).getByRole('button', { name: 'Grant access' }).click();
    await expect(
      page.getByRole('button', { name: `Disable access for ${farm.worker.name}` }),
    ).toBeVisible();
  });

  test('admin deletes a farm and its users can no longer sign in', async ({
    admin,
    freshFarm,
    signInAs,
    page,
    browser,
  }) => {
    const farm = await freshFarm();
    await signInAs(admin, '/admin/farms');
    await page.getByLabel('Search by farm name').fill(farm.name);
    await page.getByRole('button', { name: 'Search' }).click();
    await page.getByRole('button', { name: `Delete farm ${farm.name}` }).click();
    await dialog(page).getByRole('button', { name: 'Delete farm' }).click();
    await expect(page.getByText('No farms found')).toBeVisible();

    const gone = await browser.newContext();
    const response = await gone.request.post('/api/v1/auth/signin', {
      data: { email: farm.owner.email, password: farm.owner.password },
    });
    expect(response.ok()).toBeFalsy();
    await gone.close();
  });

  test('farm users cannot open the page', async ({ sharedFarm, signInAs, page }) => {
    await signInAs(sharedFarm.owner);
    await page.goto('/admin/farms');
    await expect(page).not.toHaveURL(/\/admin\/farms/);
  });
});
