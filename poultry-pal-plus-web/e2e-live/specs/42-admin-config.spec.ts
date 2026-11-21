import { Page } from '@playwright/test';
import { expect, test } from '../fixtures';
import { confirmDelete, dialog } from '../pages/records';

const toast = (page: Page, text: string) =>
  page.locator('mat-snack-bar-container').filter({ hasText: text });

const code = (prefix: string): string =>
  `E2E_${prefix}_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 5)}`.toUpperCase();

const entry = (page: Page, name: string) =>
  page
    .getByRole('list', { name: 'Configuration entries' })
    .getByRole('listitem')
    .filter({
      has: page.getByRole('heading', { name }),
    });

test.describe('admin app config', () => {
  test.beforeEach(({ diagnostics }) => {
    // The system admin has no farm, so sync bootstrap answers 403 (candidate defect).
    diagnostics.expect({ status: 403, match: /sync\/bootstrap/ });
  });

  test('lists the seeded entries and protects the mail settings from deletion', async ({
    admin,
    signInAs,
    page,
    shot,
  }) => {
    await signInAs(admin, '/admin/app-config');
    await expect(page.getByRole('heading', { name: 'App config', level: 1 })).toBeVisible();
    const mailHost = entry(page, 'MAIL_HOST');
    await expect(mailHost).toBeVisible();
    await expect(mailHost.getByRole('button', { name: 'Edit MAIL_HOST' })).toBeVisible();
    await expect(mailHost.getByRole('button', { name: 'Delete MAIL_HOST' })).toHaveCount(0);
    await expect(entry(page, 'MAIL_PASS')).toContainText('********');
    await shot(page, 'admin-config', 'list');
  });

  test('an entry is created, edited and deleted', async ({ admin, signInAs, page, shot }) => {
    await signInAs(admin, '/admin/app-config');
    const name = code('PLAIN');
    await page.getByRole('button', { name: 'Add entry' }).click();
    await page.getByRole('button', { name: 'Save' }).click();
    await expect(page.getByText('Enter a code (letters, digits, underscores).')).toBeVisible();
    await expect(page.getByText('Enter a value (up to 250 characters).')).toBeVisible();
    await shot(page, 'admin-config', 'validation');

    await page.getByLabel('Code').fill(name.toLowerCase());
    await page.getByLabel('Value', { exact: true }).fill('first value');
    await page.getByRole('button', { name: 'Save' }).click();
    await expect(toast(page, 'Configuration created.')).toBeVisible();
    await expect(entry(page, name)).toContainText('first value');

    await entry(page, name)
      .getByRole('button', { name: `Edit ${name}` })
      .click();
    await page.getByLabel('Value', { exact: true }).fill('second value');
    await page.getByRole('button', { name: 'Save' }).click();
    await expect(toast(page, 'Configuration updated.')).toBeVisible();
    await expect(entry(page, name)).toContainText('second value');
    await shot(page, 'admin-config', 'edited');

    await entry(page, name)
      .getByRole('button', { name: `Delete ${name}` })
      .click();
    await dialog(page, 'Delete configuration?').getByRole('button', { name: 'Cancel' }).click();
    await expect(entry(page, name)).toBeVisible();
    await entry(page, name)
      .getByRole('button', { name: `Delete ${name}` })
      .click();
    await confirmDelete(page, 'Delete configuration?');
    await expect(toast(page, 'Configuration deleted.')).toBeVisible();
    await expect(entry(page, name)).toHaveCount(0);
  });

  test('a sensitive value is masked and a blank value keeps the secret', async ({
    admin,
    signInAs,
    page,
  }) => {
    await signInAs(admin, '/admin/app-config');
    const name = code('SECRET');
    await page.getByRole('button', { name: 'Add entry' }).click();
    await page.getByLabel('Code').fill(name);
    await page.getByLabel('Value', { exact: true }).fill('s3cr3t-value');
    await page.getByRole('button', { name: 'Save' }).click();
    await expect(toast(page, 'Configuration created.')).toBeVisible();
    await expect(entry(page, name)).toContainText('********');
    await expect(entry(page, name)).not.toContainText('s3cr3t-value');

    await entry(page, name)
      .getByRole('button', { name: `Edit ${name}` })
      .click();
    await expect(page.getByLabel('Value', { exact: true })).toHaveAttribute('type', 'password');
    await page.getByLabel('Value', { exact: true }).fill('');
    await page.getByRole('button', { name: 'Save' }).click();
    await expect(toast(page, 'Configuration updated.')).toBeVisible();
    await expect(entry(page, name)).toContainText('********');

    await entry(page, name)
      .getByRole('button', { name: `Delete ${name}` })
      .click();
    await confirmDelete(page, 'Delete configuration?');
    await expect(entry(page, name)).toHaveCount(0);
  });

  test('a duplicate code is rejected', async ({ admin, signInAs, page, diagnostics }) => {
    diagnostics.expect({ status: 400 });
    diagnostics.expect({ status: 409 });
    await signInAs(admin, '/admin/app-config');
    await page.getByRole('button', { name: 'Add entry' }).click();
    await page.getByLabel('Code').fill('MAIL_HOST');
    await page.getByLabel('Value', { exact: true }).fill('evil.example.com');
    await page.getByRole('button', { name: 'Save' }).click();
    await expect(page.getByRole('alert').or(page.locator('mat-snack-bar-container'))).toContainText(
      /exist|duplicate|already/i,
    );
    await expect(entry(page, 'MAIL_HOST')).not.toContainText('evil.example.com');
  });

  test('the dashboard shows the email log table for the system admin', async ({
    admin,
    signInAs,
    page,
    shot,
  }) => {
    await signInAs(admin, '/dashboard');
    const log = page.getByTestId('email-log');
    await expect(log.getByRole('heading', { name: 'Email log' })).toBeVisible();
    await expect(
      log.getByTestId('email-log-row').or(log.getByTestId('email-log-empty')).first(),
    ).toBeVisible();
    await shot(page, 'admin-config', 'email-log');
  });

  test('the email log shows ten emails at a time and pages through them', async ({
    admin,
    signInAs,
    page,
  }) => {
    await signInAs(admin, '/dashboard');
    const log = page.getByTestId('email-log');
    const rows = log.getByTestId('email-log-row');
    await expect(rows.first()).toBeVisible();
    expect(await rows.count()).toBeLessThanOrEqual(10);
    await expect(log.getByTestId('email-log-prev')).toBeDisabled();
    const next = log.getByTestId('email-log-next');
    if (await next.isEnabled()) {
      await next.click();
      await expect(log.getByText('Page 2')).toBeVisible();
      await expect(log.getByTestId('email-log-prev')).toBeEnabled();
    }
  });
});
