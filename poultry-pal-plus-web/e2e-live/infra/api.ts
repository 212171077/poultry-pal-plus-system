import { APIRequestContext, expect, request as playwrightRequest } from '@playwright/test';
import { urls } from './env';
import { waitForEmail } from './mailpit';
import { SYSTEM_ADMIN_EMAIL } from './seed';

export type RoleName = 'admin' | 'owner' | 'manager' | 'worker' | 'productionManager';

export interface Account {
  role: RoleName;
  name: string;
  surname: string;
  email: string;
  password: string;
}

export interface Farm {
  name: string;
  owner: Account;
  manager: Account;
  worker: Account;
  productionManager: Account;
}

let counter = 0;
const unique = (): string =>
  `${Date.now().toString(36)}${(counter++).toString(36)}${Math.random().toString(36).slice(2, 5)}`;

/** All calls go through the web origin (nginx proxy), exactly as the browser reaches the API. */
export async function newApi(): Promise<APIRequestContext> {
  return playwrightRequest.newContext({ baseURL: urls.web });
}

export async function signInApi(
  api: APIRequestContext,
  account: Pick<Account, 'email' | 'password'>,
) {
  const response = await api.post('/api/v1/auth/signin', {
    data: { username: account.email, password: account.password },
  });
  expect(response.status(), `sign in ${account.email}: ${await response.text()}`).toBe(200);
  return response;
}

export function systemAdmin(): Account {
  return {
    role: 'admin',
    name: 'System',
    surname: 'Admin',
    email: process.env['E2E_ADMIN_EMAIL'] ?? SYSTEM_ADMIN_EMAIL,
    password: process.env['E2E_ADMIN_PASSWORD'] ?? '',
  };
}

/** Registers a farm owner and approves the account the way the admin does: via the emailed link. */
export async function registerApprovedOwner(farmName: string): Promise<Account> {
  const id = unique();
  const owner: Account = {
    role: 'owner',
    name: 'Olivia',
    surname: `Owner${id}`.slice(0, 40),
    email: `owner.${id}@example.com`,
    password: 'E2e-Passw0rd!',
  };
  const api = await newApi();
  const signup = await api.post('/api/v1/auth/signup', {
    data: {
      name: owner.name,
      surname: owner.surname,
      email: owner.email,
      phoneNumber: `082${id.replace(/\D/g, '').padEnd(7, '1').slice(0, 7)}`,
      password: owner.password,
      farmName,
      farmCountry: 'South Africa',
    },
  });
  expect(signup.status(), `sign up ${owner.email}: ${await signup.text()}`).toBeLessThan(300);

  const html = await waitForEmail({
    to: systemAdmin().email,
    subject: 'awaiting approval',
    bodyIncludes: owner.email,
  });
  const token = /approval\?token=([A-Za-z0-9_-]+)/.exec(html)?.[1];
  if (!token) throw new Error('Approval token not found in the admin email.');
  const decision = await api.post('/api/auth/approval', { form: { token, decision: 'approve' } });
  expect(decision.status(), await decision.text()).toBe(200);
  await api.dispose();
  return owner;
}

/** Owner adds a team member; the backend sets the initial password to the phone number. */
async function addTeamMember(
  api: APIRequestContext,
  role: 'manager' | 'worker' | 'productionManager',
): Promise<Account> {
  const id = unique();
  const phone = `083${id.replace(/\D/g, '').padEnd(7, '2').slice(0, 7)}`;
  const account: Account = {
    role,
    name: role === 'worker' ? 'Wanda' : role === 'manager' ? 'Mandla' : 'Pieter',
    surname: `${role}${id}`.slice(0, 40),
    email: `${role}.${id}@example.com`,
    password: phone,
  };
  const response = await api.post('/api/v1/team', {
    data: {
      name: account.name,
      surname: account.surname,
      email: account.email,
      phoneNumber: phone,
      role: role === 'manager' ? 'ROLE_FARM_MANAGER' : 'ROLE_FARM_WORKER',
    },
  });
  expect(response.status(), `add ${role}: ${await response.text()}`).toBeLessThan(300);
  return account;
}

/** A complete, isolated farm: owner, manager, worker and a production manager. */
export async function provisionFarm(label = 'E2E Farm'): Promise<Farm> {
  const name = `${label} ${unique()}`;
  const owner = await registerApprovedOwner(name);
  const api = await newApi();
  await signInApi(api, owner);
  const manager = await addTeamMember(api, 'manager');
  const worker = await addTeamMember(api, 'worker');
  const productionManager = await addTeamMember(api, 'productionManager');

  const team = await api.get('/api/v1/team');
  const members = ((await team.json()) as { data: { id: string; email: string }[] }).data;
  const target = members.find((m) => m.email === productionManager.email);
  if (!target) throw new Error('Production manager not found in the team list.');
  const grant = await api.put(`/api/v1/team/${target.id}/production-access`, {
    data: { granted: true },
  });
  expect(grant.status(), await grant.text()).toBeLessThan(300);
  await api.dispose();
  return { name, owner, manager, worker, productionManager };
}
