import { Page } from '@playwright/test';
import { expect, test } from '../fixtures';
import { Finding, auditPage, focusIndicators, format } from '../pages/quality';

const FARM_PAGES: [name: string, path: string][] = [
  ['dashboard', '/dashboard'],
  ['coops', '/coops'],
  ['sales', '/sales'],
  ['mortality', '/mortality'],
  ['expenses', '/expenses'],
  ['eggs', '/eggs'],
  ['reminders', '/reminders'],
  ['reports', '/reports'],
  ['team', '/team'],
  ['sync', '/sync'],
  ['settings', '/settings'],
  ['production-dashboard', '/production/dashboard'],
  ['production-batches', '/production/batches'],
  ['production-schedule', '/production/schedule'],
  ['production-plans', '/production/plans'],
  ['production-placements', '/production/placements'],
  ['production-results', '/production/results'],
  ['production-settings', '/production/settings'],
];

const PUBLIC_PAGES: [name: string, path: string][] = [
  ['login', '/login'],
  ['register', '/register'],
  ['forgot-password', '/forgot-password'],
];

const MIN_TARGET = 48;

async function settled(page: Page): Promise<void> {
  await page.waitForLoadState('networkidle').catch(() => undefined);
  await page.evaluate(() => document.fonts.ready);
}

function report(findings: Finding[], rules: string[]): string {
  return format(findings.filter((f) => rules.includes(f.rule)));
}

test.describe('layout on every signed-in page', () => {
  for (const [name, path] of FARM_PAGES) {
    test(`${name} fits the screen and its controls are reachable`, async ({
      seededFarm,
      signInAs,
      page,
    }) => {
      await signInAs(seededFarm.owner, path);
      await expect(page.getByRole('heading', { level: 1 }).first()).toBeVisible();
      await settled(page);
      const findings = await auditPage(page, MIN_TARGET);
      const layout = report(findings, ['horizontal-overflow', 'outside-viewport']);
      expect(layout, `layout problems on ${path}`).toBe('');
    });
  }

  for (const [name, path] of PUBLIC_PAGES) {
    test(`${name} fits the screen`, async ({ page }) => {
      await page.goto(path);
      await expect(page.getByRole('heading').first()).toBeVisible();
      await settled(page);
      const findings = await auditPage(page, MIN_TARGET);
      expect(report(findings, ['horizontal-overflow', 'outside-viewport'])).toBe('');
    });
  }
});

test.describe('touch targets', () => {
  // DEFECT: several controls are smaller than the 48px target the project requires on handsets
  // (40px icon buttons in the top bar, 40px toggle buttons, 44px action buttons).
  test(
    'every control is at least 48px tall on a handset',
    { tag: '@DEF-006' },
    async ({ seededFarm, signInAs, shell, page }) => {
      test.skip(!shell.isHandset(), 'handset only');
      test.setTimeout(120_000);
      const problems: Finding[] = [];
      await signInAs(seededFarm.owner, '/dashboard');
      for (const [, path] of FARM_PAGES) {
        await page.goto(path);
        await expect(page.getByRole('heading', { level: 1 }).first()).toBeVisible();
        await settled(page);
        problems.push(
          ...(await auditPage(page, MIN_TARGET)).filter((f) => f.rule === 'touch-target'),
        );
      }
      expect(format(problems), 'controls under the minimum size').toBe('');
    },
  );
});

test.describe('accessibility basics', () => {
  for (const [name, path] of [...FARM_PAGES, ...PUBLIC_PAGES]) {
    test(`${name} has names, a single heading and unique ids`, async ({
      seededFarm,
      signInAs,
      page,
    }) => {
      if (PUBLIC_PAGES.some(([, p]) => p === path)) await page.goto(path);
      else await signInAs(seededFarm.owner, path);
      await expect(page.getByRole('heading').first()).toBeVisible();
      await settled(page);
      const findings = await auditPage(page, MIN_TARGET);
      const rules = ['no-accessible-name', 'image-alt', 'single-h1', 'duplicate-id', 'html-lang'];
      const named = findings.filter((f) => !f.detail.includes('mdc-switch'));
      expect(report(named, rules), `accessibility problems on ${path}`).toBe('');
    });
  }

  // DEFECT: the aria-label is set on the <mat-slide-toggle> host, not on the inner switch button,
  // so screen readers announce an unnamed switch.
  test(
    'equipment switches have an accessible name',
    { tag: '@DEF-007' },
    async ({ freshFarm, farmApi, signInAs, page }) => {
      const farm = await freshFarm();
      expect(
        (await (await farmApi(farm.owner)).api.get('/api/v1/production/equipment')).status(),
      ).toBe(200);
      await signInAs(farm.owner, '/production/settings');
      const toggle = page.getByRole('switch').first();
      await expect(toggle).toBeVisible();
      await expect(toggle).toHaveAccessibleName(/Enable/, { timeout: 3000 });
    },
  );

  for (const [name, path] of [FARM_PAGES[0], FARM_PAGES[1], FARM_PAGES[2], FARM_PAGES[10]]) {
    test(`${name} shows a visible keyboard focus indicator`, async ({
      seededFarm,
      signInAs,
      page,
    }) => {
      await signInAs(seededFarm.owner, path);
      await expect(page.getByRole('heading', { level: 1 }).first()).toBeVisible();
      await settled(page);
      expect(format(await focusIndicators(page)), `focus indicators on ${path}`).toBe('');
    });
  }

  test('the sign-in form can be completed with the keyboard alone', async ({
    sharedFarm,
    page,
  }) => {
    await page.goto('/login');
    await page
      .getByLabel(/email|username/i)
      .first()
      .focus();
    await page.keyboard.type(sharedFarm.owner.email);
    await page.keyboard.press('Tab');
    await page.keyboard.type(sharedFarm.owner.password);
    await page.keyboard.press('Enter');
    await expect(page).toHaveURL(/\/dashboard/);
  });

  // DEFECT: href="#main-content" resolves against <base href="/">, so the link navigates to
  // "/#main-content" and leaves the current page instead of moving focus.
  test(
    'the skip link moves focus to the main content',
    { tag: '@DEF-008' },
    async ({ sharedFarm, signInAs, page }) => {
      await signInAs(sharedFarm.owner, '/sales');
      await page.keyboard.press('Tab');
      const skip = page.getByRole('link', { name: 'Skip to main content' });
      await expect(skip).toBeFocused();
      await page.keyboard.press('Enter');
      await expect(page).toHaveURL(/\/sales/, { timeout: 3000 });
      await expect(page.locator('#main-content')).toBeFocused({ timeout: 3000 });
    },
  );

  test('dialogs trap focus and Escape closes them', async ({ seededFarm, signInAs, page }) => {
    await signInAs(seededFarm.owner, '/sales');
    await page
      .getByRole('button', { name: /Add sale|New sale|Record sale/ })
      .first()
      .click();
    const dialog = page.getByRole('dialog');
    await expect(dialog).toBeVisible();
    await expect.poll(() => dialog.evaluate((d) => d.contains(document.activeElement))).toBe(true);
    for (let i = 0; i < 30; i++) {
      await page.keyboard.press('Tab');
      const inside = await dialog.evaluate((d) => d.contains(document.activeElement));
      const where = await page.evaluate(() => document.activeElement?.outerHTML.slice(0, 80));
      expect(inside, `focus left the dialog on tab ${i + 1}: ${where}`).toBe(true);
    }
    await page.keyboard.press('Escape');
    await expect(dialog).toBeHidden();
  });
});

test.describe('mobile frame', () => {
  test('the fixed bars never cover the end of the page', async ({
    seededFarm,
    signInAs,
    shell,
    page,
  }) => {
    test.skip(!shell.isHandset(), 'handset only');
    await signInAs(seededFarm.owner, '/dashboard');
    for (const path of ['/dashboard', '/coops', '/sales', '/settings']) {
      if (path !== '/dashboard') await page.goto(path);
      await expect(page.getByRole('heading', { level: 1 }).first()).toBeVisible();
      await settled(page);
      await expect
        .poll(
          () =>
            page.evaluate(() => {
              const scroller = document.querySelector('mat-sidenav-content')!;
              scroller.scrollTo({ top: scroller.scrollHeight, behavior: 'instant' });
              const bar = document.querySelector<HTMLElement>('app-bottom-nav');
              const main = document.querySelector<HTMLElement>('#main-content');
              if (!bar || !main) return 0;
              const content =
                main.getBoundingClientRect().bottom -
                parseFloat(getComputedStyle(main).paddingBottom);
              return Math.max(0, content - bar.getBoundingClientRect().top);
            }),
          { message: `${path} content hidden by the bottom bar`, timeout: 10_000 },
        )
        .toBeLessThanOrEqual(1);
    }
  });

  test('a form dialog scrolls and its actions stay reachable', async ({
    seededFarm,
    signInAs,
    shell,
    page,
    shot,
  }) => {
    test.skip(!shell.isHandset(), 'handset only');
    await signInAs(seededFarm.owner, '/expenses');
    await page
      .getByRole('button', { name: /Add expense|New expense|Record expense/ })
      .first()
      .click();
    const dialog = page.getByRole('dialog');
    await expect(dialog).toBeVisible();
    await shot(page, 'ui-quality', 'expense-dialog-mobile');
    const box = await dialog.boundingBox();
    const viewport = page.viewportSize()!;
    expect(box!.width).toBeLessThanOrEqual(viewport.width);
    expect(box!.y + box!.height).toBeLessThanOrEqual(viewport.height + 1);
    await expect(
      dialog.getByRole('button', { name: /^(Save|Add|Cancel)/ }).first(),
    ).toBeInViewport();
  });
});
