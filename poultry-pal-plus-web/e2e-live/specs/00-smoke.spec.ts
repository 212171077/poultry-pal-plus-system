import { expect, test } from '@playwright/test';
import { urls } from '../infra/env';

test.describe('stack smoke', () => {
  test('web app is served and redirects guests to the login page', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveURL(/\/login/);
  });

  test('web proxies the API to the real backend', async ({ request }) => {
    const response = await request.get('/api/v1/auth/me');
    expect(response.status()).toBe(401);
  });

  test('backend is connected to an empty, dedicated database and seeded the system admin', async ({
    request,
  }) => {
    const signin = await request.post(`${urls.backend}/api/v1/auth/signin`, {
      data: {
        username: process.env['E2E_ADMIN_EMAIL'],
        password: process.env['E2E_ADMIN_PASSWORD'],
      },
    });
    expect(signin.status(), await signin.text()).toBe(200);
  });
});
