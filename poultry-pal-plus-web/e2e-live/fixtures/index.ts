import { test as base, expect, Page } from '@playwright/test';
import { Account, Farm, RoleName, provisionFarm, systemAdmin } from '../infra/api';
import { FarmApi, SeededFarmData, seedFarmData } from '../infra/farm-api';
import { LoginPage } from '../pages/login.page';
import { ShellPage } from '../pages/shell.page';
import { Diagnostics } from './diagnostics';
import { Shot, captureFailure, makeShot } from './screenshots';

interface TestFixtures {
  /** Browser problems recorded during the test; unexpected ones fail it (see Diagnostics). */
  diagnostics: Diagnostics;
  /** Screenshot after the page has settled: `await shot(page, 'coops', 'empty-state')`. */
  shot: Shot;
  loginPage: LoginPage;
  shell: ShellPage;
  /** Signs the given account in through the UI on `page` and waits for the shell. */
  signInAs: (account: Account, returnTo?: string) => Promise<void>;
  /** A brand-new farm for tests that create or change data, so tests never share state. */
  freshFarm: () => Promise<Farm>;
  /** Backend client signed in as the given account; closed automatically after the test. */
  farmApi: (account: Account) => Promise<FarmApi>;
}

interface WorkerFixtures {
  /** One farm (owner, manager, worker, production manager) shared by read-only/permission tests. */
  sharedFarm: Farm;
  admin: Account;
  /** A farm with two coops and sample records; read-only tests must not change it. */
  seededFarm: Farm & { data: SeededFarmData };
}

export const test = base.extend<TestFixtures, WorkerFixtures>({
  sharedFarm: [
    async ({}, use) => {
      await use(await provisionFarm('Shared Farm'));
    },
    { scope: 'worker', timeout: 180_000 },
  ],

  seededFarm: [
    async ({}, use) => {
      const farm = await provisionFarm('Seeded Farm');
      await use({ ...farm, data: await seedFarmData(farm) });
    },
    { scope: 'worker', timeout: 240_000 },
  ],

  admin: [
    async ({}, use) => {
      await use(systemAdmin());
    },
    { scope: 'worker' },
  ],

  diagnostics: [
    async ({ context }, use, testInfo) => {
      const diagnostics = new Diagnostics();
      diagnostics.attach(context);
      await use(diagnostics);
      await diagnostics.attachTo(testInfo);
      const unexpected = diagnostics.unexpected();
      if (unexpected.length > 0 && testInfo.status === testInfo.expectedStatus) {
        throw new Error(`Unexpected browser/API problems:\n${diagnostics.format(unexpected)}`);
      }
    },
    { auto: true },
  ],

  // Declared after diagnostics so it runs its teardown first and can still see the open pages.
  shot: async ({ context }, use, testInfo) => {
    await use(makeShot(testInfo));
    if (testInfo.status !== testInfo.expectedStatus) {
      await captureFailure(context.pages(), testInfo);
    }
  },

  loginPage: async ({ page }, use) => use(new LoginPage(page)),
  shell: async ({ page }, use) => use(new ShellPage(page)),

  signInAs: async ({ page, loginPage }, use) => {
    await use(async (account, returnTo = '/dashboard') => {
      await loginPage.signInAndWait(account, returnTo);
    });
  },

  farmApi: async ({}, use) => {
    const opened: FarmApi[] = [];
    await use(async (account) => {
      const api = await FarmApi.as(account);
      opened.push(api);
      return api;
    });
    await Promise.all(opened.map((api) => api.dispose()));
  },

  freshFarm: async ({}, use) => {
    await use(() => provisionFarm('Fresh Farm'));
  },
});

export { expect };
export type { Account, Farm, Page, RoleName };
