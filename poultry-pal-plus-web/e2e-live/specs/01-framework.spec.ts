import { existsSync } from 'node:fs';
import { expect, test } from '../fixtures';

test.describe('framework: role sessions and shell', () => {
  test('owner sees farm management and production navigation', async ({
    page,
    sharedFarm,
    signInAs,
    shell,
    shot,
  }) => {
    await signInAs(sharedFarm.owner);
    await shell.expectLoaded();
    const labels = await shell.navLabels();
    expect(labels).toEqual(expect.arrayContaining(['Dashboard', 'Team', 'Production']));
    expect(labels).not.toContain('App config');
    expect(await shell.accountSummary()).toContain(sharedFarm.owner.email);
    await shot(page, 'dashboard', 'owner-signed-in');
  });

  test('worker has no manager, production or admin navigation', async ({
    sharedFarm,
    signInAs,
    shell,
  }) => {
    await signInAs(sharedFarm.worker);
    await shell.expectLoaded();
    const labels = await shell.navLabels();
    expect(labels).toContain('Dashboard');
    for (const hidden of ['Team', 'Production', 'App config']) expect(labels).not.toContain(hidden);
  });

  test('production manager sees Production but not Team', async ({
    sharedFarm,
    signInAs,
    shell,
  }) => {
    await signInAs(sharedFarm.productionManager);
    const labels = await shell.navLabels();
    expect(labels).toContain('Production');
    expect(labels).not.toContain('Team');
  });

  test('system admin sees App config', async ({ admin, signInAs, shell, diagnostics }) => {
    // Candidate defect (Phase 6): the admin has no farm, so sync bootstrap answers 403.
    diagnostics.expect({ status: 403, match: /sync\/bootstrap/ });
    await signInAs(admin);
    expect(await shell.navLabels()).toContain('App config');
  });

  test('signing out returns to the login page', async ({ sharedFarm, signInAs, shell, page }) => {
    await signInAs(sharedFarm.manager);
    await shell.signOut();
    await expect(page).toHaveURL(/\/login/);
  });

  test('a wrong password is rejected and the declared 401 is not reported as a problem', async ({
    sharedFarm,
    loginPage,
    diagnostics,
    shot,
    page,
  }) => {
    diagnostics.expect({ status: 401, match: /signin/ });
    await loginPage.goto('/login');
    await loginPage.signIn({ email: sharedFarm.owner.email, password: 'definitely-wrong' });
    await expect(loginPage.error).toBeVisible();
    expect(diagnostics.issues.some((i) => i.status === 401)).toBe(true);
    expect(diagnostics.unexpected()).toEqual([]);
    const path = await shot(page, 'login', 'wrong-password');
    expect(existsSync(path)).toBe(true);
  });
});
