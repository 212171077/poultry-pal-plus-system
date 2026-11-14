import { Locator, Page, expect } from '@playwright/test';
import { openApp } from '../../e2e/helpers';
import { Account } from '../infra/api';

export class LoginPage {
  readonly email: Locator;
  readonly password: Locator;
  readonly submit: Locator;
  readonly keepSignedIn: Locator;
  readonly error: Locator;

  constructor(readonly page: Page) {
    this.email = page.getByLabel('Email');
    this.password = page.getByLabel('Password', { exact: true });
    this.submit = page.getByRole('button', { name: 'Sign in' });
    this.keepSignedIn = page.getByLabel('Keep me signed in on this device');
    this.error = page.getByRole('alert');
  }

  async goto(path = '/login'): Promise<void> {
    await openApp(this.page, path);
  }

  async signIn(account: Pick<Account, 'email' | 'password'>): Promise<void> {
    await this.email.fill(account.email);
    await this.password.fill(account.password);
    await this.submit.click();
  }

  /** Signs in and waits for the shell; use for tests that are not about the login itself. */
  async signInAndWait(
    account: Pick<Account, 'email' | 'password'>,
    returnTo = '/dashboard',
  ): Promise<void> {
    await this.goto(returnTo);
    await expect(this.page).toHaveURL(/\/login/);
    await this.signIn(account);
    await expect(this.page).toHaveURL(new RegExp(`${returnTo.split('?')[0]}(\\?.*)?$`), {
      timeout: 20_000,
    });
  }
}
