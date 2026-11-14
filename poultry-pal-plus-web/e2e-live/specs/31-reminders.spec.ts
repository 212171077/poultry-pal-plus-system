import { expect, test } from '../fixtures';
import { isoDaysAgo } from '../infra/farm-api';
import { dialog } from '../pages/records';

test.describe('reminders', () => {
  test('a farm without coops has nothing to remind about', async ({
    freshFarm,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    await signInAs(farm.owner, '/reminders');
    await expect(page.getByRole('heading', { name: 'Reminders', level: 1 })).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Nothing needs attention' })).toBeVisible();
    for (const tab of ['Upcoming (0)', 'Completed (0)']) {
      await page.getByRole('radio', { name: tab }).click();
    }
    await expect(page.getByRole('heading', { name: 'Nothing completed yet' })).toBeVisible();
    await shot(page, 'reminders', 'empty');
  });

  test('tab counts match the listed tasks and a task can be completed', async ({
    freshFarm,
    farmApi,
    signInAs,
    page,
    shot,
  }) => {
    const farm = await freshFarm();
    const api = await farmApi(farm.owner);
    // A batch that arrived a few days ago gets a vaccination and feeding schedule.
    await api.createCoop({
      coopName: 'Scheduled Coop',
      numberOfChickens: 300,
      chickenArrivalDate: isoDaysAgo(5),
    });
    await signInAs(farm.owner, '/reminders');
    const tabs = page.getByRole('radiogroup', { name: 'Show reminders' });
    await expect(tabs).toBeVisible();

    const count = async (name: string) =>
      Number(
        /\((\d+)\)/.exec(
          await page.getByRole('radio', { name: new RegExp(name) }).innerText(),
        )?.[1],
      );
    await shot(page, 'reminders', 'attention');

    for (const tab of ['Needs attention', 'Upcoming']) {
      await page.getByRole('radio', { name: new RegExp(tab) }).click();
      const expected = await count(tab);
      await expect(page.getByTestId('reminder-row')).toHaveCount(expected);
    }

    const attention = await count('Needs attention');
    const upcoming = await count('Upcoming');
    expect(attention + upcoming, 'a new batch should have scheduled tasks').toBeGreaterThan(0);

    await page
      .getByRole('radio', { name: new RegExp(attention > 0 ? 'Needs attention' : 'Upcoming') })
      .click();
    const first = page.getByTestId('reminder-row').first();
    const name = (await first.locator('.title').innerText()).trim();
    await first.getByRole('button', { name: /^Complete / }).click();
    const form = dialog(page, 'Mark as completed');
    await form.getByLabel(/Comment/).fill('Done by E2E');
    await form.getByRole('button', { name: 'Mark completed' }).click();
    await expect(form).toBeHidden();

    await page.getByRole('radio', { name: /Completed/ }).click();
    const done = page.getByTestId('reminder-row').filter({ hasText: name });
    await expect(done.first()).toContainText('Done by E2E');
    await expect(done.first()).toContainText('Synced', { timeout: 30_000 });
    expect(await count('Completed')).toBeGreaterThan(0);
  });
});
