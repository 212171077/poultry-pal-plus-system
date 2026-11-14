import { Locator, Page, expect } from '@playwright/test';
import { openApp } from '../../e2e/helpers';

/** Helpers shared by the record pages (coops, sales, mortality, expenses, eggs). */

export async function choose(page: Page, scope: Locator, label: string, option: string | RegExp) {
  await scope.getByRole('combobox', { name: label }).click();
  await page.getByRole('option', { name: option }).click();
}

export function dialog(page: Page, name: string | RegExp): Locator {
  return page.getByRole('dialog', { name });
}

export function rows(page: Page, testId: string): Locator {
  return page.getByTestId(testId);
}

export async function rowAction(row: Locator, page: Page, action: string): Promise<void> {
  await row.getByRole('button', { name: /More actions/ }).click();
  await page.getByRole('menuitem', { name: action }).click();
}

export async function confirmDelete(page: Page, title: string): Promise<void> {
  const confirm = dialog(page, title);
  await expect(confirm).toBeVisible();
  await confirm.getByRole('button', { name: 'Delete' }).click();
  await expect(confirm).toBeHidden();
}

export function coopCard(page: Page, name: string): Locator {
  return page.getByTestId('coop-card').filter({ has: page.getByRole('heading', { name }) });
}

export const marker = (prefix: string): string =>
  `${prefix} ${Date.now().toString(36)}${Math.random().toString(36).slice(2, 5)}`;

/**
 * Opens a deep link once the first sync has delivered the coops. Following the link straight
 * after sign-in races the sync and the form is skipped (see the candidate defect in the report).
 */
export async function openWhenSynced(page: Page, url: string): Promise<void> {
  await expect(page.getByTestId('coop-card').first()).toBeVisible({ timeout: 30_000 });
  await openApp(page, url);
}
