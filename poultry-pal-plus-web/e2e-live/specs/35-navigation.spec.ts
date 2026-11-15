import { expect, test } from '../fixtures';
import { dialog } from '../pages/records';

const DESTINATIONS: [label: string, path: RegExp, heading: RegExp][] = [
  ['Dashboard', /\/dashboard/, /Good|Hello|Welcome/],
  ['Coops & batches', /\/coops/, /Coops & batches/],
  ['Sales', /\/sales/, /Sales/],
  ['Mortality', /\/mortality/, /Mortality/],
  ['Expenses', /\/expenses/, /Expenses/],
  ['Egg production', /\/eggs/, /Egg production/],
  ['Reminders', /\/reminders/, /Reminders/],
  ['Reports', /\/reports/, /Reports/],
  ['Team', /\/team/, /Team/],
  ['Production', /\/production/, /Production/],
  ['Sync center', /\/sync/, /Sync center/],
  ['Settings', /\/settings/, /Settings/],
];

test.describe('navigation', () => {
  test('every navigation entry opens its page for the owner', async ({
    sharedFarm,
    signInAs,
    shell,
    page,
  }) => {
    await signInAs(sharedFarm.owner);
    for (const [label, path, heading] of DESTINATIONS) {
      await shell.goTo(label);
      await expect(page, label).toHaveURL(path);
      await expect(page.getByRole('heading', { level: 1 }).first(), label).toHaveText(heading);
    }
  });

  test('the current page is marked in the navigation', async ({ sharedFarm, signInAs, shell }) => {
    await signInAs(sharedFarm.owner, '/sales');
    const nav = await shell.openNavigation();
    await expect(nav.getByRole('link', { name: 'Sales' })).toHaveAttribute('aria-current', 'page');
    await expect(nav.getByRole('link', { name: 'Coops & batches' })).not.toHaveAttribute(
      'aria-current',
      'page',
    );
  });

  test('Quick add opens a record form from anywhere', async ({
    seededFarm,
    signInAs,
    shell,
    page,
    shot,
  }) => {
    await signInAs(seededFarm.owner, '/reports');
    await expect(page.getByTestId('coop-report').or(page.getByText('No coops yet'))).toBeVisible();
    if (shell.isHandset()) {
      await page
        .getByRole('button', { name: /Quick add|Add/ })
        .first()
        .click();
    } else {
      await page.getByRole('button', { name: 'Quick add' }).click();
    }
    await shot(page, 'navigation', 'quick-add');
    await page.getByRole('dialog').getByRole('link', { name: 'Record mortality' }).click();
    await expect(page).toHaveURL(/\/mortality/);
    await expect(dialog(page, /Record mortality/)).toBeVisible();
  });

  test('the N shortcut opens quick add on desktop and is ignored while typing', async ({
    sharedFarm,
    signInAs,
    shell,
    page,
  }) => {
    test.skip(shell.isHandset(), 'keyboard shortcut is a desktop feature');
    await signInAs(sharedFarm.owner, '/settings');
    await page.getByLabel('First name').focus();
    await page.keyboard.type('n');
    await expect(page.getByRole('dialog')).toHaveCount(0);
    await page.locator('#main-content').click({ position: { x: 5, y: 5 } });
    await page.keyboard.press('n');
    await expect(page.getByRole('dialog', { name: 'Quick add' })).toBeVisible();
  });

  test('the handset bottom bar reaches the main areas', async ({
    sharedFarm,
    signInAs,
    shell,
    page,
    shot,
  }) => {
    test.skip(!shell.isHandset(), 'bottom bar is only shown on phones');
    await signInAs(sharedFarm.owner, '/dashboard');
    const bar = page.getByRole('navigation').last();
    await shot(page, 'navigation', 'bottom-bar');
    await bar.getByRole('link', { name: 'Coops' }).click();
    await expect(page).toHaveURL(/\/coops/);
    await bar.getByRole('link', { name: 'Reminders' }).click();
    await expect(page).toHaveURL(/\/reminders/);
    await bar.getByRole('link', { name: 'Home' }).click();
    await expect(page).toHaveURL(/\/dashboard/);
  });

  test('a worker is sent away from manager-only pages', async ({ sharedFarm, signInAs, page }) => {
    await signInAs(sharedFarm.worker, '/dashboard');
    await page.goto('/team');
    await expect(page).not.toHaveURL(/\/team$/);
  });
});
