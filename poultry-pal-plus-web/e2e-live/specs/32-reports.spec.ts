import { expect, test } from '../fixtures';
import { waitForEmail } from '../infra/mailpit';

test.describe('reports', () => {
  test('totals and the by-coop table match the seeded data', async ({
    seededFarm,
    signInAs,
    page,
    shot,
  }) => {
    await signInAs(seededFarm.owner, '/reports');
    await expect(page.getByRole('heading', { name: 'Reports', level: 1 })).toBeVisible();
    const totals = page.getByRole('region', { name: 'Totals' });
    await expect(totals).toContainText(/4[\s,]?450/);
    await expect(totals).toContainText(/1[\s,]?550/);
    await expect(totals).toContainText(/2[\s,]?900/);

    const table = page.getByTestId('coop-report');
    const layers = table.getByRole('row').filter({ hasText: seededFarm.data.layers.name });
    const broilers = table.getByRole('row').filter({ hasText: seededFarm.data.broilers.name });
    await expect(layers).toContainText('495');
    await expect(layers).toContainText('600');
    await expect(broilers).toContainText('988');
    await expect(broilers).toContainText('12');
    await shot(page, 'reports', 'seeded');
  });

  test('a farm without coops shows the empty state', async ({ freshFarm, signInAs, page }) => {
    const farm = await freshFarm();
    await signInAs(farm.owner, '/reports');
    await expect(page.getByRole('heading', { name: 'No coops yet' })).toBeVisible();
  });

  test('the farm report is emailed to the owner through Mailpit', async ({
    seededFarm,
    signInAs,
    page,
  }) => {
    await signInAs(seededFarm.owner, '/reports');
    await expect(page.getByTestId('coop-report')).toBeVisible();
    await page.getByRole('button', { name: 'Email report' }).click();
    await expect(page.getByText(/Email sent|will be emailed/).first()).toBeVisible();
    const html = await waitForEmail({ to: seededFarm.owner.email, subject: 'Farm Report' });
    expect(html.length).toBeGreaterThan(100);
  });

  test('the coop schedule is emailed to the owner through Mailpit', async ({
    seededFarm,
    signInAs,
    page,
  }) => {
    await signInAs(seededFarm.owner, '/reports');
    await expect(page.getByTestId('coop-report')).toBeVisible();
    await page.getByRole('button', { name: 'Email schedule' }).click();
    await waitForEmail({ to: seededFarm.owner.email, subject: 'Chicken Health Schedule' });
  });

  test('the report PDF downloads from the real backend', async ({ seededFarm, signInAs, page }) => {
    await signInAs(seededFarm.owner, '/reports');
    await expect(page.getByTestId('coop-report')).toBeVisible();
    const download = page.waitForEvent('download');
    await page.getByRole('button', { name: 'Report PDF' }).click();
    expect((await download).suggestedFilename()).toMatch(/\.pdf$/i);
  });
});
