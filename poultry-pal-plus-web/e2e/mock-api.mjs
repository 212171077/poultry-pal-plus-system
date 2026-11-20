// In-memory stand-in for the `/api/v1` sync endpoints, used only by the e2e tests.
// It mirrors the backend contract (envelope, opId idempotency, optimistic versions, tombstones)
// closely enough to prove the offline → online round trip without a JVM.
// Each Playwright test isolates its data with a `pp_mock_tenant` cookie.
//
// Auth mirrors `/api/v1/auth`: sign-in sets an HttpOnly session cookie (a browser-session cookie
// unless `rememberMe`), and sync calls without a session answer 401. Every tenant starts with
// `thandi@example.com` / `secret1`. Sign-up creates a new, empty farm for the new owner.
// Test code may bypass auth with `?tenant=<name>` to act as "another device".

export const MOCK_EMAIL = 'thandi@example.com';
export const MOCK_PASSWORD = 'secret1';
const SESSION_COOKIE = 'pp_mock_session';

const LIST_KEYS = {
  COOP: 'coops',
  SALE: 'sales',
  MORTALITY: 'mortalities',
  EXPENSE: 'expenses',
  EGG_PACKAGING: 'eggPackagingRecords',
};

const tenants = new Map();
const sessions = new Map(); // token → tenant name
/** email → { password, tenant } for owners registered through sign-up. */
const registered = new Map();

function createTenant(name, { user = {}, farmName = 'Sunrise Poultry', withCoop = true } = {}) {
  const now = new Date().toISOString();
  const tenant = {
    name,
    version: 1,
    farmId: `farm-${name}`,
    farmName,
    addresses: [],
    user: {
      id: `user-${name}`,
      name: 'Thandi',
      surname: 'Mokoena',
      email: MOCK_EMAIL,
      farmId: `farm-${name}`,
      farmOwner: true,
      active: true,
      roles: ['ROLE_USER', 'ROLE_FARM_MANAGER'],
      roleFriendlyNames: ['User', 'Farm manager'],
      userCoopIds: [],
      ...user,
    },
    records: new Map(), // `${type}:${id}` → { type, id, coopId, version, deleted, data }
    results: new Map(), // opId → result
  };
  if (!withCoop) return tenant;
  tenant.records.set('COOP:coop-1', {
    type: 'COOP',
    id: 'coop-1',
    coopId: 'coop-1',
    version: 1,
    deleted: false,
    data: {
      id: 'coop-1',
      coopName: 'Layer House A',
      coopType: 'LAYERS',
      growthPhase: 'PRODUCTION_FINISHING_PHASE',
      numberOfChickens: 500,
      // 20 weeks old: a layer flock in production, so no phase change is due.
      chickenArrivalDate: new Date(Date.now() - 140 * 24 * 60 * 60 * 1000).toISOString(),
      createdDate: now,
      active: true,
      version: 1,
      reminder: {
        vaccines: [{ id: 'vac-1', vaccineName: 'Newcastle booster', dueDate: now, done: false }],
        feeds: [
          {
            id: 'feed-1',
            feedType: 'Layer mash',
            dueDate: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString(),
            done: false,
          },
        ],
        medicines: [],
      },
    },
  });
  return tenant;
}

function readCookie(req, name) {
  const match = new RegExp(`(?:^|;\\s*)${name}=([^;]+)`).exec(req.headers.cookie ?? '');
  return match ? decodeURIComponent(match[1]) : null;
}

function tenantNamed(name) {
  if (!tenants.has(name)) tenants.set(name, createTenant(name));
  return tenants.get(name);
}

/** The test's farm (from the `pp_mock_tenant` cookie), used to sign in. */
function cookieTenant(req, url) {
  return tenantNamed(
    url.searchParams.get('tenant') ?? readCookie(req, 'pp_mock_tenant') ?? 'default',
  );
}

/** The signed-in farm, or null without a valid session (the `?tenant=` backdoor counts as one). */
function sessionTenant(req, url) {
  const backdoor = url.searchParams.get('tenant');
  if (backdoor) return tenantNamed(backdoor);
  const name = sessions.get(readCookie(req, SESSION_COOKIE) ?? '');
  return name ? tenantNamed(name) : null;
}

function startSession(res, tenant, rememberMe) {
  const token = `s-${Date.now()}-${Math.random().toString(36).slice(2)}`;
  sessions.set(token, tenant.name);
  const maxAge = rememberMe === false ? '' : '; Max-Age=2592000';
  res.setHeader(
    'set-cookie',
    `${SESSION_COOKIE}=${token}; Path=/; HttpOnly; SameSite=Lax${maxAge}`,
  );
}

function fail(res, status, errorCode, message, errors) {
  send(res, status, { success: false, message, errorCode, ...(errors ? { errors } : {}) });
}

function signUpErrors(body) {
  const errors = [];
  const text = (field, min, max) => {
    const value = String(body?.[field] ?? '').trim();
    if (value.length < min || value.length > max) {
      errors.push({ field, message: `size must be between ${min} and ${max}` });
    }
  };
  text('name', 2, 50);
  text('surname', 2, 50);
  text('email', 3, 50);
  text('phoneNumber', 1, 15);
  text('password', 6, 120);
  text('farmName', 1, 100);
  return errors;
}

function send(res, status, body) {
  res.writeHead(status, { 'content-type': 'application/json', 'cache-control': 'no-store' });
  res.end(JSON.stringify(body));
}

const ok = (res, data) => send(res, 200, { success: true, message: 'OK', data });

async function readJson(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  return chunks.length ? JSON.parse(Buffer.concat(chunks).toString('utf8')) : null;
}

function farmSnapshot(tenant) {
  return {
    id: tenant.farmId,
    farmName: tenant.farmName,
    version: 1,
    address: tenant.addresses[0] ?? null,
    addresses: tenant.addresses,
  };
}

function changesSince(tenant, since) {
  const changes = {
    cursor: tenant.version,
    hasMore: false,
    resetRequired: false,
    farm: since === 0 ? farmSnapshot(tenant) : null,
    coops: [],
    sales: [],
    mortalities: [],
    expenses: [],
    eggPackagingRecords: [],
    tombstones: [],
  };
  for (const record of tenant.records.values()) {
    if (record.version <= since) continue;
    if (record.deleted) {
      if (since > 0) {
        changes.tombstones.push({
          entityType: record.type,
          entityId: record.id,
          coopId: record.coopId,
          version: record.version,
          deletedAt: new Date().toISOString(),
        });
      }
      continue;
    }
    changes[LIST_KEYS[record.type]].push(record.data);
  }
  return changes;
}

function validate(op) {
  const p = op.payload ?? {};
  const errors = [];
  if (op.entityType === 'EXPENSE') {
    if (!p.expenseDate) errors.push('expenseDate: must not be null');
    if (!p.expenseType) errors.push('expenseType: must not be blank');
    if (typeof p.amount !== 'number' || p.amount < 0) errors.push('amount: must be >= 0');
  }
  if (op.entityType === 'COOP' && !p.coopName) errors.push('coopName: must not be blank');
  if (op.entityType === 'MORTALITY' && !(p.numberOfDeaths > 0)) {
    errors.push('numberOfDeaths: must be greater than 0');
  }
  return errors;
}

const BOX_EGGS = { '6 eggs box': 6, '12 eggs box': 12, '18 eggs box': 18, '30 eggs box': 30, '60 eggs box': 60 };

/** Server-computed fields, as the backend fills them in. */
function derive(type, data) {
  if (type === 'SALE') {
    const byPackaging = (data.quantitySold ?? 0) * (data.pricePerUnit ?? 0);
    const byDozen = (data.numberOfDozensSold ?? 0) * (data.salePricePerDozen ?? 0);
    const byChicken = (data.numberOfChickensSold ?? 0) * (data.salePricePerChicken ?? 0);
    data.totalSaleAmount = byPackaging || byDozen || byChicken;
  }
  if (type === 'EGG_PACKAGING') {
    data.totalEggs = (BOX_EGGS[String(data.boxSize).toLowerCase()] ?? 0) * data.numberOfBoxes;
  }
  return data;
}

function touch(tenant, record, fields) {
  record.version = ++tenant.version;
  record.data = {
    ...record.data,
    ...fields,
    version: record.version,
    updatedAt: new Date().toISOString(),
  };
}

function childrenOf(tenant, coopId) {
  return [...tenant.records.values()].filter(
    (r) => r.type !== 'COOP' && !r.deleted && r.coopId === coopId,
  );
}

/** `COOP` `ACTION`: new batch or phase transition (see the backend `SyncService`). */
function applyCoopAction(tenant, op, base) {
  const coop = tenant.records.get(`COOP:${op.entityId}`);
  const rejected = (errorCode, message) => ({ ...base, status: 'REJECTED', errorCode, message });
  if (op.entityType !== 'COOP' || !coop || coop.deleted)
    return rejected('NOT_FOUND', 'Coop not found');
  const p = op.payload ?? {};
  if (p.action === 'NEW_BATCH') {
    for (const child of childrenOf(tenant, op.entityId)) {
      child.deleted = true;
      child.version = ++tenant.version;
    }
    touch(tenant, coop, { ...p.batch });
  } else if (p.action === 'PHASE_TRANSITION') {
    const targetId = p.targetCoopId && p.targetCoopId !== op.entityId ? p.targetCoopId : null;
    if (targetId) {
      const target = tenant.records.get(`COOP:${targetId}`);
      if (!target || target.deleted) return rejected('NOT_FOUND', 'Target coop not found');
      if (target.data.numberOfChickens > 0) {
        return rejected('VALIDATION', 'The target coop still has chickens');
      }
      touch(tenant, target, {
        growthPhase: p.newGrowthPhase,
        numberOfChickens: coop.data.numberOfChickens,
        chickenArrivalDate: coop.data.chickenArrivalDate ?? null,
      });
      for (const child of childrenOf(tenant, op.entityId)) {
        child.coopId = targetId;
        touch(tenant, child, { coopId: targetId });
      }
      touch(tenant, coop, {
        growthPhase: 'BROODING_PHASE',
        numberOfChickens: 0,
        chickenArrivalDate: null,
      });
    } else {
      touch(tenant, coop, { growthPhase: p.newGrowthPhase });
    }
  } else {
    return rejected('VALIDATION', 'Unknown coop action');
  }
  return { ...base, status: 'APPLIED', version: coop.version, serverRecord: coop.data };
}

function applyOp(tenant, op) {
  const replay = tenant.results.get(op.opId);
  if (replay) return { ...replay, duplicate: true };

  const base = {
    opId: op.opId,
    entityType: op.entityType,
    entityId: op.entityId,
    coopId: op.coopId,
  };
  if (!LIST_KEYS[op.entityType]) {
    return { ...base, status: 'REJECTED', errorCode: 'UNSUPPORTED', message: 'Not mocked' };
  }
  if (op.operation === 'ACTION') return applyCoopAction(tenant, op, base);
  const key = `${op.entityType}:${op.entityId}`;
  const current = tenant.records.get(key);
  const exists = current && !current.deleted;
  const conflict = (message) => ({
    ...base,
    status: 'CONFLICT',
    errorCode: 'VERSION_CONFLICT',
    message,
    version: current?.version ?? null,
    serverRecord: exists ? current.data : null,
  });

  if (op.operation === 'DELETE') {
    if (!exists) return { ...base, status: 'APPLIED', version: current?.version ?? null };
    if (op.baseVersion != null && op.baseVersion !== current.version) {
      return conflict('Record was changed by someone else');
    }
    current.deleted = true;
    current.version = ++tenant.version;
    if (op.entityType === 'COOP') {
      for (const child of childrenOf(tenant, op.entityId)) {
        child.deleted = true;
        child.version = ++tenant.version;
      }
    }
    return { ...base, status: 'APPLIED', version: tenant.version };
  }

  if (exists && op.baseVersion !== current.version) {
    return conflict('Record was changed by someone else');
  }
  if (!exists && op.baseVersion != null) return conflict('Record no longer exists');
  const errors = validate(op);
  if (errors.length) {
    return { ...base, status: 'REJECTED', errorCode: 'VALIDATION', message: 'Invalid', errors };
  }
  if (op.entityType !== 'COOP' && !tenant.records.get(`COOP:${op.coopId}`)) {
    return { ...base, status: 'REJECTED', errorCode: 'NOT_FOUND', message: 'Coop not found' };
  }

  const version = ++tenant.version;
  const data = derive(op.entityType, {
    ...(exists ? current.data : {}),
    ...op.payload,
    id: op.entityId,
    version,
    updatedAt: new Date().toISOString(),
    updatedBy: tenant.user.id,
  });
  if (op.entityType !== 'COOP') data.coopId = op.coopId;
  tenant.records.set(key, {
    type: op.entityType,
    id: op.entityId,
    coopId: op.coopId,
    version,
    deleted: false,
    data,
  });
  return { ...base, status: 'APPLIED', version, serverRecord: data };
}

/** Handles `/api/**` and `/__mock/**`. Returns false when the path is not an API path. */
export async function handleMockApi(req, res) {
  const url = new URL(req.url ?? '/', 'http://localhost');
  const path = url.pathname;
  if (!path.startsWith('/api/') && !path.startsWith('/__mock/')) return false;
  if (path.startsWith('/api/v1/auth/') && req.method === 'POST') {
    await handleAuth(req, res, url, path);
    return true;
  }

  if (path === '/__mock/records') {
    const tenant = cookieTenant(req, url);
    const type = url.searchParams.get('type') ?? 'EXPENSE';
    const marker = url.searchParams.get('marker') ?? '';
    const records = [...tenant.records.values()]
      .filter((r) => r.type === type && !r.deleted)
      .map((r) => r.data)
      .filter((data) => !marker || JSON.stringify(data).includes(marker));
    send(res, 200, records);
    return true;
  }

  const tenant = sessionTenant(req, url);
  if (!tenant) {
    fail(res, 401, 'UNAUTHORIZED', 'Full authentication is required');
    return true;
  }

  if (req.method === 'GET' && path === '/api/v1/auth/me') {
    ok(res, tenant.user);
  } else if (req.method === 'GET' && path === '/api/v1/team') {
    ok(res, [
      tenant.user,
      {
        id: 'worker-1',
        name: 'Sipho',
        surname: 'Dlamini',
        email: 'sipho@example.com',
        phoneNumber: '0712345678',
        farmId: tenant.farmId,
        farmOwner: false,
        active: true,
        roles: ['ROLE_USER', 'ROLE_FARM_WORKER'],
        roleFriendlyNames: ['User', 'Farm worker'],
        userCoopIds: ['coop-1'],
      },
    ]);
  } else if (path === '/api/v1/farm/addresses' && req.method === 'POST') {
    const body = await readJson(req);
    tenant.addresses.push({ ...body, id: `addr-${tenant.addresses.length + 1}-${Date.now()}` });
    tenant.version += 1;
    ok(res, farmSnapshot(tenant));
  } else if (path.startsWith('/api/v1/farm/addresses/') && ['PUT', 'DELETE'].includes(req.method)) {
    const id = decodeURIComponent(path.split('/').pop());
    const index = tenant.addresses.findIndex((address) => address.id === id);
    if (index < 0) {
      fail(res, 404, 'NOT_FOUND', 'Address not found');
      return;
    }
    if (req.method === 'PUT') tenant.addresses[index] = { ...(await readJson(req)), id };
    else tenant.addresses.splice(index, 1);
    tenant.version += 1;
    ok(res, farmSnapshot(tenant));
  } else if (req.method === 'GET' && path === '/api/v1/farm/archived-batches') {
    ok(res, [
      {
        id: 'arch-1',
        coopName: 'Old broilers',
        coopType: 'BROILER',
        numberOfChickens: 200,
        chickenArrivalDate: '2025-01-05T00:00:00.000Z',
        archivedDate: '2025-02-20T00:00:00.000Z',
        totalSales: 1500,
        totalExpenses: 900,
        totalDeaths: 10,
        totalEggs: 0,
        salesCount: 3,
        expensesCount: 4,
        mortalityCount: 2,
        eggRecordCount: 0,
      },
    ]);
  } else if (req.method === 'GET' && path === '/api/v1/sync/bootstrap') {
    ok(res, {
      user: tenant.user,
      team: [tenant.user],
      settings: { userId: tenant.user.id, farmId: tenant.farmId, currency: 'ZAR' },
      snapshot: changesSince(tenant, 0),
    });
  } else if (req.method === 'GET' && path === '/api/v1/sync/changes') {
    ok(res, changesSince(tenant, Number(url.searchParams.get('since') ?? 0)));
  } else if (req.method === 'POST' && path === '/api/v1/sync/push') {
    const body = await readJson(req);
    const results = (body?.operations ?? []).map((op) => {
      const result = applyOp(tenant, op);
      if (!result.duplicate) tenant.results.set(op.opId, result);
      return result;
    });
    ok(res, { results, serverVersion: tenant.version });
  } else {
    send(res, 404, { success: false, message: `No mock for ${req.method} ${path}` });
  }
  return true;
}

async function handleAuth(req, res, url, path) {
  const body = await readJson(req);
  if (path === '/api/v1/auth/signin') {
    const email = String(body?.username ?? '')
      .trim()
      .toLowerCase();
    const owner = registered.get(email);
    const tenant = owner ? tenantNamed(owner.tenant) : cookieTenant(req, url);
    const password = owner ? owner.password : MOCK_PASSWORD;
    if (email !== tenant.user.email.toLowerCase() || body?.password !== password) {
      fail(res, 401, 'INVALID_CREDENTIALS', 'Bad credentials');
      return;
    }
    startSession(res, tenant, body?.rememberMe);
    ok(res, tenant.user);
  } else if (path === '/api/v1/auth/signup') {
    const errors = signUpErrors(body);
    if (errors.length) {
      fail(res, 400, 'VALIDATION_ERROR', 'Validation failed', errors);
      return;
    }
    const email = String(body.email).trim().toLowerCase();
    if (registered.has(email) || email === MOCK_EMAIL) {
      fail(res, 409, 'CONFLICT', 'Error: Email is already in use!');
      return;
    }
    const name = `signup-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    tenants.set(
      name,
      createTenant(name, {
        withCoop: false,
        farmName: body.farmName,
        user: { name: body.name, surname: body.surname, email, phoneNumber: body.phoneNumber },
      }),
    );
    registered.set(email, { password: body.password, tenant: name });
    send(res, 201, { success: true, message: 'User registered successfully!', data: null });
  } else if (path === '/api/v1/auth/refresh') {
    const tenant = sessionTenant(req, url);
    if (tenant) ok(res, tenant.user);
    else fail(res, 401, 'UNAUTHORIZED', 'Refresh token is missing or expired');
  } else if (path === '/api/v1/auth/forgot-password') {
    ok(res, null);
  } else if (path === '/api/v1/auth/reset-password') {
    if (body?.code === '123456') ok(res, null);
    else fail(res, 400, 'BAD_REQUEST', 'The code is invalid or has expired');
  } else if (path === '/api/v1/auth/logout') {
    sessions.delete(readCookie(req, SESSION_COOKIE) ?? '');
    res.setHeader('set-cookie', `${SESSION_COOKIE}=; Path=/; HttpOnly; Max-Age=0`);
    ok(res, null);
  } else {
    send(res, 404, { success: false, message: `No mock for ${req.method} ${path}` });
  }
}
