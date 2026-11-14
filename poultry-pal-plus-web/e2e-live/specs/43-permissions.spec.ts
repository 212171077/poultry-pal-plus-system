import { expect, test } from '../fixtures';
import { RoleName, newApi, signInApi } from '../infra/api';

type Who = RoleName | 'anonymous';

const ROUTES: { path: string; allowed: RoleName[] }[] = [
  { path: '/team', allowed: ['owner', 'manager', 'admin'] },
  { path: '/production/dashboard', allowed: ['owner', 'productionManager'] },
  { path: '/admin/app-config', allowed: ['admin'] },
  { path: '/reports', allowed: ['owner', 'manager', 'worker', 'productionManager', 'admin'] },
  { path: '/sales', allowed: ['owner', 'manager', 'worker', 'productionManager', 'admin'] },
];

const ROLES: RoleName[] = ['owner', 'manager', 'worker', 'productionManager', 'admin'];

test.describe('route access by role', () => {
  for (const route of ROUTES) {
    for (const role of ROLES) {
      const allowed = route.allowed.includes(role);
      test(`${role} ${allowed ? 'can open' : 'is redirected away from'} ${route.path}`, async ({
        sharedFarm,
        admin,
        signInAs,
        diagnostics,
        page,
      }) => {
        diagnostics.expect({ status: 403, match: /sync\/bootstrap/ });
        const account = role === 'admin' ? admin : sharedFarm[role];
        await signInAs(account);
        await page.goto(route.path);
        if (allowed) {
          await expect(page).toHaveURL(new RegExp(`${route.path}`));
        } else {
          await expect(page).not.toHaveURL(new RegExp(`${route.path}`));
        }
      });
    }
  }

  for (const route of ROUTES.filter((r) => r.path !== '/sales')) {
    test(`an anonymous visitor to ${route.path} is sent to sign in`, async ({ page }) => {
      await page.goto(route.path);
      await expect(page).toHaveURL(/\/login/);
    });
  }
});

const ENDPOINTS: { method: 'get'; url: string; allowed: Who[] }[] = [
  { method: 'get', url: '/api/v1/team', allowed: ['owner', 'manager'] },
  { method: 'get', url: '/api/v1/production/snapshot', allowed: ['owner', 'productionManager'] },
  { method: 'get', url: '/api/v1/production/settings', allowed: ['owner', 'productionManager'] },
  { method: 'get', url: '/api/v1/production/equipment', allowed: ['owner', 'productionManager'] },
  { method: 'get', url: '/api/v1/admin/app-config', allowed: ['admin'] },
];

test.describe('API access by role', () => {
  for (const endpoint of ENDPOINTS) {
    for (const who of [...ROLES, 'anonymous'] as Who[]) {
      const allowed = endpoint.allowed.includes(who);
      const expectation = allowed ? 'is allowed' : who === 'anonymous' ? 'gets 401' : 'gets 403';
      test(`${who} ${expectation} on GET ${endpoint.url}`, async ({ sharedFarm, admin }) => {
        const api = await newApi();
        try {
          if (who !== 'anonymous') {
            await signInApi(api, who === 'admin' ? admin : sharedFarm[who]);
          }
          const status = (await api[endpoint.method](endpoint.url)).status();
          if (allowed) expect(status).toBe(200);
          else expect(status).toBe(who === 'anonymous' ? 401 : 403);
        } finally {
          await api.dispose();
        }
      });
    }
  }

  test('a worker cannot change team roles or production access', async ({
    sharedFarm,
    farmApi,
  }) => {
    const worker = await farmApi(sharedFarm.worker);
    const owner = await farmApi(sharedFarm.owner);
    const team = (await (await owner.api.get('/api/v1/team')).json()).data as {
      id: string;
      email: string;
    }[];
    const target = team.find((m) => m.email === sharedFarm.productionManager.email)?.id;
    expect(target).toBeTruthy();
    const role = await worker.api.patch(`/api/v1/team/${target}/role`, {
      data: { role: 'ROLE_FARM_MANAGER' },
    });
    expect(role.status()).toBe(403);
    const access = await worker.api.put(`/api/v1/team/${target}/production-access`, {
      data: { granted: false },
    });
    expect(access.status()).toBe(403);
    const remove = await worker.api.delete(`/api/v1/team/${target}`);
    expect(remove.status()).toBe(403);
  });

  test('a manager cannot write app config', async ({ sharedFarm, farmApi }) => {
    const manager = await farmApi(sharedFarm.manager);
    const create = await manager.api.post('/api/v1/admin/app-config', {
      data: { code: 'E2E_FORBIDDEN', description: 'x' },
    });
    expect(create.status()).toBe(403);
  });
});
