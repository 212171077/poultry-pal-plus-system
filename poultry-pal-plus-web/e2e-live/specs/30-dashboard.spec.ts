import { expect, test } from '../fixtures';
import { dialog } from '../pages/records';

const kpi = (page: import('@playwright/test').Page, label: string) =>
  page.locator('app-kpi-card').filter({ has: page.getByText(label, { exact: true }) });

test.describe('dashboard', () => {
  test('shows a greeting and key figures that match the seeded farm', async ({
    seededFarm,
    signInAs,
    page,
    shot,
  }) => {
    await signInAs(seededFarm.owner, '/dashboard');
    await expect(page.getByRole('heading', { level: 1 })).toContainText(/Good|Hello|Welcome/);
    await expect(page.getByRole('region', { name: 'Key figures' })).toBeVisible();
    await expect(kpi(page, 'Live birds')).toContainText(/1[\s,]?483/);
    await expect(kpi(page, 'Eggs packaged')).toContainText(/600/);
    await expect(kpi(page, 'Sales')).toContainText(/4[\s,]?450/);
    await expect(kpi(page, 'Sales')).toContainText(/4[\s,]?000/); // unpaid hint
    await expect(kpi(page, 'Expenses')).toContainText(/1[\s,]?550/);
    await expect(kpi(page, 'Profit')).toContainText(/2[\s,]?900/);
    await expect(kpi(page, 'Losses')).toContainText('17');
    await expect(page.getByRole('heading', { name: 'Recent activity' })).toBeVisible();
    await shot(page, 'dashboard', 'seeded');
  });

  test('the period filter fits, is labelled and each coop has a summary card', async ({
    seededFarm,
    signInAs,
    page,
    shot,
  }) => {
    await signInAs(seededFarm.owner, '/dashboard');
    const summary = page.getByTestId('range-summary');
    await expect(summary).toHaveText('Summary for all recorded data');
    const group = page.locator('app-range-filter');
    await expect(group.getByText('30 days', { exact: true })).toHaveCount(0);
    await expect(group.getByText('All', { exact: true })).toBeVisible();
    await group.getByText('7 days', { exact: true }).click();
    await expect(summary).toHaveText('Summary for the last 7 days');
    await group.getByText('90 days', { exact: true }).click();
    await expect(summary).toHaveText('Summary for the last 90 days');
    const box = await group.boundingBox();
    const viewport = page.viewportSize();
    expect(box!.x + box!.width).toBeLessThanOrEqual(viewport!.width);

    const cards = page.locator('app-coop-summary-card');
    await expect(cards.first()).toBeVisible();
    await expect(cards.first()).toContainText(/Total/);
    await expect(cards.first()).toContainText(/Available/);
    await expect(cards.first()).toContainText(/Financial summary/);
    await shot(page, 'dashboard', 'coop-cards');
  });

  test('layers coops show the daily egg trend and a production verdict', async ({
    seededFarm,
    signInAs,
    page,
    shot,
  }) => {
    await signInAs(seededFarm.owner, '/dashboard');
    const panel = page.getByTestId('egg-production');
    await expect(panel).toBeVisible();
    await expect(panel.locator('app-line-chart svg')).toBeVisible();
    await expect(page.getByTestId('egg-status')).toContainText(/production/i);
    await panel.scrollIntoViewIfNeeded();
    await shot(page, 'dashboard', 'egg-production');
  });

  test('a new farm shows empty states instead of charts', async ({
    freshFarm,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    await signInAs(farm.owner, '/dashboard');
    await expect(page.getByText('No records in this period').first()).toBeVisible();
    await expect(page.getByText('No activity yet')).toBeVisible();
    await expect(page.getByText('Nothing due today')).toBeVisible();
    await expect(kpi(page, 'Live birds')).toContainText('0');
    await shot(page, 'dashboard', 'empty');
  });

  test('quick actions open the matching form', async ({ seededFarm, signInAs, page }) => {
    await signInAs(seededFarm.owner, '/dashboard');
    await expect(kpi(page, 'Live birds')).toContainText(/1[\s,]?483/);
    const actions = page
      .getByRole('region', { name: 'Quick actions' })
      .or(
        page
          .locator('section')
          .filter({ has: page.getByRole('heading', { name: 'Quick actions' }) }),
      );
    await actions.getByRole('link', { name: 'Record a sale' }).click();
    await expect(page).toHaveURL(/\/sales/);
    await expect(dialog(page, 'Record a sale')).toBeVisible();
  });

  test('the header has no duplicate Log eggs button and non-admins get no email log', async ({
    seededFarm,
    signInAs,
    page,
  }) => {
    await signInAs(seededFarm.owner, '/dashboard');
    await expect(kpi(page, 'Live birds')).toContainText(/1[\s,]?483/);
    await expect(page.getByRole('link', { name: 'Log eggs' })).toHaveCount(0);
    await expect(page.getByTestId('email-log')).toHaveCount(0);
  });

  test('workers do not get the manager-only quick action', async ({
    seededFarm,
    signInAs,
    page,
  }) => {
    await signInAs(seededFarm.worker, '/dashboard');
    const panel = page
      .locator('section')
      .filter({ has: page.getByRole('heading', { name: 'Quick actions' }) });
    await expect(panel.getByRole('link', { name: 'Record a sale' })).toBeVisible();
    await expect(panel.getByRole('link', { name: 'Add a coop' })).toHaveCount(0);
  });
});
