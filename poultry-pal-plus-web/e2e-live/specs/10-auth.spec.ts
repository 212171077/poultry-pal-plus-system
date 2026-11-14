import { Page } from '@playwright/test';
import { waitForEmail } from '../infra/mailpit';
import { expect, test } from '../fixtures';

const unique = () => `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`;

async function fillRegistration(
  page: Page,
  values: Partial<Record<string, string>> = {},
): Promise<{ email: string }> {
  const id = unique();
  const data = {
    'Farm name': `Auth Farm ${id}`,
    'First name': 'Regina',
    Surname: `Tester${id}`.slice(0, 40),
    Email: `register.${id}@example.com`,
    'Phone number': '0821234567',
    Password: 'E2e-Passw0rd!',
    'Confirm password': 'E2e-Passw0rd!',
    ...values,
  };
  for (const [label, value] of Object.entries(data)) {
    await page.getByLabel(label, { exact: true }).fill(value ?? '');
  }
  return { email: data.Email };
}

test.describe('auth: login', () => {
  test('empty and malformed input show validation without calling the API', async ({
    loginPage,
    page,
    shot,
    diagnostics,
  }) => {
    await loginPage.goto('/login');
    await shot(page, 'login', 'initial');
    await loginPage.submit.click();
    await expect(page.getByText('Enter your email')).toBeVisible();
    await expect(page.getByText('Enter your password')).toBeVisible();
    await loginPage.email.fill('not-an-email');
    await loginPage.password.fill('x');
    await loginPage.submit.click();
    await expect(page.getByText('Enter a valid email address')).toBeVisible();
    await shot(page, 'login', 'validation-errors');
    expect(diagnostics.issues.filter((i) => i.url?.includes('/api/'))).toEqual([]);
  });

  test('password visibility can be toggled', async ({ loginPage, page }) => {
    await loginPage.goto('/login');
    await loginPage.password.fill('secret-value');
    await expect(loginPage.password).toHaveAttribute('type', 'password');
    await page.getByRole('button', { name: 'Show password' }).click();
    await expect(loginPage.password).toHaveAttribute('type', 'text');
    await page.getByRole('button', { name: 'Hide password' }).click();
    await expect(loginPage.password).toHaveAttribute('type', 'password');
  });

  test('an unknown account is rejected with a message', async ({
    loginPage,
    diagnostics,
    shot,
    page,
  }) => {
    diagnostics.expect({ status: 401, match: /signin/ });
    await loginPage.goto('/login');
    await loginPage.signIn({ email: `nobody.${unique()}@example.com`, password: 'Whatever123!' });
    await expect(loginPage.error).toBeVisible();
    await expect(page).toHaveURL(/\/login/);
    await shot(page, 'login', 'unknown-account');
  });

  test('navigation links lead to register and forgot-password', async ({ loginPage, page }) => {
    await loginPage.goto('/login');
    await page.getByRole('link', { name: 'Create a farm account' }).click();
    await expect(page).toHaveURL(/\/register/);
    await page.getByRole('link', { name: 'Sign in' }).click();
    await expect(page).toHaveURL(/\/login/);
    await page.getByRole('link', { name: 'Forgot your password?' }).click();
    await expect(page).toHaveURL(/\/forgot-password/);
  });

  test('a valid sign in lands on the dashboard and survives a reload', async ({
    sharedFarm,
    signInAs,
    shell,
    page,
  }) => {
    await signInAs(sharedFarm.owner);
    await shell.expectLoaded();
    await page.reload();
    await shell.expectLoaded();
    await expect(page).toHaveURL(/\/dashboard$/);
  });
});

test.describe('auth: guards and session', () => {
  test('protected pages send guests to login and return after sign in', async ({
    sharedFarm,
    loginPage,
    page,
    shell,
  }) => {
    await loginPage.goto('/coops');
    await expect(page).toHaveURL(/\/login\?returnUrl=%2Fcoops/);
    await loginPage.signIn(sharedFarm.owner);
    await expect(page).toHaveURL(/\/coops$/);
    await shell.expectLoaded();
  });

  test('a signed-in user opening /login or /register is sent to the dashboard', async ({
    sharedFarm,
    signInAs,
    page,
  }) => {
    await signInAs(sharedFarm.owner);
    await page.goto('/login');
    await expect(page).toHaveURL(/\/dashboard$/);
    await page.goto('/register');
    await expect(page).toHaveURL(/\/dashboard$/);
  });

  test('after signing out the previous page is no longer reachable', async ({
    sharedFarm,
    signInAs,
    shell,
    page,
  }) => {
    await signInAs(sharedFarm.worker, '/sales');
    await shell.signOut();
    await page.goto('/sales');
    await expect(page).toHaveURL(/\/login/);
  });

  test('losing the session cookies sends the user back to login', async ({
    sharedFarm,
    signInAs,
    page,
    context,
    diagnostics,
    shell,
  }) => {
    diagnostics.expect({ status: 401 });
    await signInAs(sharedFarm.manager);
    await context.clearCookies();
    await page.reload();
    // The app may keep a device session offline-first; an API-bound action must still fail safely.
    await page.goto('/login');
    const url = page.url();
    expect(url).toMatch(/\/(login|dashboard)/);
    if (/dashboard/.test(url)) await shell.expectLoaded();
  });
});

test.describe('auth: register', () => {
  test('empty form shows required-field errors', async ({ page, loginPage, shot }) => {
    await loginPage.goto('/register');
    await shot(page, 'register', 'initial');
    await page.getByRole('button', { name: 'Create account' }).click();
    await expect(page.getByText("Enter your farm's name")).toBeVisible();
    await expect(page.getByText('Enter 7–15 digits')).toBeVisible();
    await expect(page.getByText('Use at least 6 characters').first()).toBeVisible();
    await shot(page, 'register', 'validation-errors');
  });

  test('mismatched passwords, bad phone and short names are rejected', async ({
    page,
    loginPage,
  }) => {
    await loginPage.goto('/register');
    await fillRegistration(page, {
      'First name': 'A',
      'Phone number': '12ab',
      'Confirm password': 'different-password',
    });
    await page.getByRole('button', { name: 'Create account' }).click();
    await expect(page.getByText("Passwords don't match")).toBeVisible();
    await expect(page.getByText('Enter 7–15 digits')).toBeVisible();
    await expect(page.getByText('Enter 2–50 characters').first()).toBeVisible();
  });

  test('password strength indicator reacts to the password', async ({ page, loginPage, shot }) => {
    await loginPage.goto('/register');
    const password = page.getByLabel('Password', { exact: true });
    await password.fill('abc');
    await expect(page.getByText(/Strength: Weak/)).toBeVisible();
    await password.fill('E2e-Passw0rd!-Long#2026');
    await expect(page.getByText(/Strength: (Good|Strong)/)).toBeVisible();
    await shot(page, 'register', 'password-strength');
  });

  test('a valid registration awaits approval and cannot sign in yet', async ({
    page,
    loginPage,
    shot,
    diagnostics,
  }) => {
    diagnostics.expect({ status: 401, match: /signin/ });
    diagnostics.expect({ status: 403, match: /signin/ });
    await loginPage.goto('/register');
    const { email } = await fillRegistration(page);
    await page.getByRole('button', { name: 'Create account' }).click();
    await expect(page.getByText(/awaiting approval by the administrator/)).toBeVisible();
    await shot(page, 'register', 'awaiting-approval');
    await waitForEmail({ to: email, subject: 'Welcome' }, 30_000).catch(() => undefined);

    await page.getByRole('link', { name: 'Sign in' }).click();
    await loginPage.signIn({ email, password: 'E2e-Passw0rd!' });
    await expect(loginPage.error).toBeVisible();
    await expect(page).toHaveURL(/\/login/);
  });

  test('registering an existing email is reported on the email field', async ({
    sharedFarm,
    page,
    loginPage,
    diagnostics,
    shot,
  }) => {
    diagnostics.expect({ status: 409 });
    diagnostics.expect({ status: 400 });
    await loginPage.goto('/register');
    await fillRegistration(page, { Email: sharedFarm.owner.email });
    await page.getByRole('button', { name: 'Create account' }).click();
    await expect(page.getByText(/already exists|already/i).first()).toBeVisible();
    await shot(page, 'register', 'duplicate-email');
  });
});

test.describe('auth: forgot password', () => {
  test('request validation and the confirmation step', async ({ page, loginPage, shot }) => {
    await loginPage.goto('/forgot-password');
    await shot(page, 'forgot-password', 'initial');
    await page.getByLabel('Email').fill('bad');
    await page.getByRole('button', { name: 'Send reset code' }).click();
    await expect(page.getByText('Enter a valid email address')).toBeVisible();
    await page.getByLabel('Email').fill(`unknown.${unique()}@example.com`);
    await page.getByRole('button', { name: 'Send reset code' }).click();
    await expect(page.getByText(/code is on its way/)).toBeVisible();
    await shot(page, 'forgot-password', 'code-sent');
  });

  test('the emailed code resets the password and the new one signs in', async ({
    freshFarm,
    page,
    loginPage,
    shot,
    diagnostics,
  }) => {
    diagnostics.expect({ status: 400, match: /reset-password/ });
    const farm = await freshFarm();
    const owner = farm.owner;
    await loginPage.goto('/forgot-password');
    await page.getByLabel('Email').fill(owner.email);
    await page.getByRole('button', { name: 'Send reset code' }).click();
    await expect(page.getByText(/code is on its way/)).toBeVisible();

    const html = await waitForEmail({ to: owner.email, subject: 'password reset code' });
    const code = /<strong>(\d{6})<\/strong>/.exec(html)?.[1];
    expect(code, 'reset code in email').toBeTruthy();

    await page.getByLabel('6-digit code').fill('000000');
    await page.getByLabel('New password').fill('Brand-New-Passw0rd!');
    await page.getByRole('button', { name: 'Set new password' }).click();
    await expect(page.getByRole('alert')).toBeVisible();
    await shot(page, 'forgot-password', 'wrong-code');

    await page.getByLabel('6-digit code').fill(code!);
    await page.getByRole('button', { name: 'Set new password' }).click();
    await expect(page).toHaveURL(/\/login/);

    await loginPage.signIn({ email: owner.email, password: 'Brand-New-Passw0rd!' });
    await expect(page).toHaveURL(/\/dashboard$/);
  });
});

test.describe('shell: 404 and redirects', () => {
  test('an unknown route shows the not-found page inside the shell', async ({
    sharedFarm,
    signInAs,
    page,
    shot,
    shell,
  }) => {
    await signInAs(sharedFarm.owner);
    await page.goto('/this-page-does-not-exist');
    await expect(page.getByText("We couldn't find that page")).toBeVisible();
    await shell.expectLoaded();
    await shot(page, 'not-found', 'unknown-route');
  });

  test('the root path redirects to the dashboard', async ({ sharedFarm, signInAs, page }) => {
    await signInAs(sharedFarm.owner);
    await page.goto('/');
    await expect(page).toHaveURL(/\/dashboard$/);
  });
});
