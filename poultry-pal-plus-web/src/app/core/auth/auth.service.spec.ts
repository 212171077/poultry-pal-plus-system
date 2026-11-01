import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { AppDb } from '../../data/db/app-db';
import { ExpenseRepository } from '../../data/repositories/repositories';
import { getMeta } from '../../data/sync/local-store';
import { SyncHttpError } from '../../data/sync/sync-api';
import { SyncEngine } from '../../data/sync/sync-engine';
import {
  FakeSyncServer,
  TEST_USER,
  createTestDb,
  provideFakeSyncServer,
  provideTestDb,
} from '../../data/testing/fake-sync-server';
import { ApiError } from '../http/api-error';
import { AuthService, safeReturnUrl } from './auth.service';
import { FakeAuthApi, provideFakeAuthApi } from './testing/fake-auth-api';

describe('AuthService', () => {
  let db: AppDb;
  let server: FakeSyncServer;
  let api: FakeAuthApi;

  const OTHER_USER = {
    id: 'user-2',
    name: 'Sipho',
    surname: 'Dlamini',
    email: 'sipho@farm.test',
    farmId: 'farm-2',
    farmOwner: true,
    active: true,
  };
  const thandi = { email: TEST_USER.email!, password: 'secret1', rememberMe: true };
  const accept = () => Promise.resolve(true);
  const decline = () => Promise.resolve(false);

  function setUp(): AuthService {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideTestDb(db),
        provideFakeSyncServer(server),
        provideFakeAuthApi(api),
        provideRouter([
          { path: 'login', children: [] },
          { path: '**', children: [] },
        ]),
      ],
    });
    // Background timers are not needed: tests drive syncs through the service.
    spyOn(TestBed.inject(SyncEngine), 'start');
    return TestBed.inject(AuthService);
  }

  async function addOfflineExpense(): Promise<void> {
    await TestBed.inject(ExpenseRepository).create({
      coopId: 'coop-1',
      expenseDate: '2026-01-10T00:00:00.000Z',
      expenseType: 'Feed Costs',
      amount: 50,
      additionalInfo: null,
    });
  }

  /** Signs Thandi in and waits for the first download to finish. */
  async function signInThandi(): Promise<AuthService> {
    const auth = setUp();
    await auth.signIn(thandi, accept);
    await TestBed.inject(SyncEngine).sync();
    return auth;
  }

  function goOffline(): void {
    server.failWith = { error: new SyncHttpError('network', 0, 'offline'), sticky: true };
  }

  beforeEach(() => {
    db = createTestDb();
    server = new FakeSyncServer();
    api = new FakeAuthApi();
    api.addAccount(TEST_USER);
    api.addAccount(OTHER_USER);
    document.cookie = 'pp_session=; path=/; max-age=0';
  });

  afterEach(async () => {
    TestBed.resetTestingModule();
    document.cookie = 'pp_session=; path=/; max-age=0';
    await db.delete();
  });

  it('starts signed out on a fresh device', async () => {
    const auth = setUp();
    expect(await auth.restore()).toBeFalse();
    expect(auth.signedIn()).toBeFalse();
  });

  it('signs in, caches the profile and downloads the farm', async () => {
    const auth = setUp();
    expect(await auth.signIn(thandi, accept)).toBe('signed-in');

    expect(auth.user()?.id).toBe(TEST_USER.id);
    expect(auth.displayName()).toBe('Thandi Mokoena');
    expect(api.signIns[0]).toEqual({
      username: 'thandi@farm.test',
      password: 'secret1',
      rememberMe: true,
    });
    expect(await getMeta(db, 'userId')).toBe(TEST_USER.id);
    expect(await getMeta(db, 'rememberMe')).toBe(1);
    await TestBed.inject(SyncEngine).sync();
    expect(await db.coops.count()).toBe(1);
  });

  it('reopens offline for a user who signed in before', async () => {
    await setUp().signIn(thandi, accept);

    const reopened = setUp();
    expect(await reopened.restore()).toBeTrue();
    expect(reopened.user()?.email).toBe('thandi@farm.test');
  });

  it('forgets a session without "keep me signed in" when the browser session ends', async () => {
    await setUp().signIn({ ...thandi, rememberMe: false }, accept);
    expect(await setUp().restore()).toBeTrue();

    document.cookie = 'pp_session=; path=/; max-age=0';
    const nextBrowserSession = setUp();
    expect(await nextBrowserSession.restore()).toBeFalse();
    // Data stays for when the same person signs in again.
    expect(await db.users.count()).toBeGreaterThan(0);
  });

  it('rejects bad credentials without touching local data', async () => {
    const auth = setUp();
    await expectAsync(auth.signIn({ ...thandi, password: 'wrong' }, accept)).toBeRejectedWith(
      jasmine.objectContaining({ code: 'INVALID_CREDENTIALS' }),
    );
    expect(auth.signedIn()).toBeFalse();
  });

  it('keeps unsynced work when the same user signs in again', async () => {
    await signInThandi();
    goOffline();
    await addOfflineExpense();

    const confirmSwitch = jasmine.createSpy('confirmSwitch').and.callFake(accept);
    expect(await setUp().signIn(thandi, confirmSwitch)).toBe('signed-in');
    expect(confirmSwitch).not.toHaveBeenCalled();
    expect(await db.outbox.count()).toBe(1);
  });

  it('asks before another account discards unsynced work, and keeps it on cancel', async () => {
    await signInThandi();
    goOffline();
    await addOfflineExpense();

    const auth = setUp();
    const confirmSwitch = jasmine.createSpy('confirmSwitch').and.callFake(decline);
    const outcome = await auth.signIn(
      { email: OTHER_USER.email, password: 'secret1', rememberMe: true },
      confirmSwitch,
    );

    expect(outcome).toBe('cancelled');
    expect(confirmSwitch).toHaveBeenCalledWith({
      unsyncedCount: 1,
      previousName: 'Thandi Mokoena',
    });
    expect(api.signOutCalls).toBe(1);
    expect(auth.signedIn()).toBeFalse();
    expect(await db.outbox.count()).toBe(1);
  });

  it("wipes the previous user's data when another account signs in", async () => {
    await signInThandi();
    goOffline();
    await addOfflineExpense();

    const auth = setUp();
    await auth.signIn({ email: OTHER_USER.email, password: 'secret1', rememberMe: true }, accept);

    expect(auth.user()?.id).toBe(OTHER_USER.id);
    expect(await db.outbox.count()).toBe(0);
    expect(await db.expenses.count()).toBe(0);
    expect(await getMeta(db, 'userId')).toBe(OTHER_USER.id);
  });

  it('signs out after syncing and wipes the device', async () => {
    const auth = await signInThandi();
    await addOfflineExpense();
    const confirmLoss = jasmine.createSpy('confirmLoss').and.callFake(decline);

    expect(await auth.signOut(confirmLoss)).toBeTrue();

    expect(confirmLoss).not.toHaveBeenCalled();
    expect(server.pushed.length).toBeGreaterThan(0);
    expect(auth.signedIn()).toBeFalse();
    expect(await db.users.count()).toBe(0);
    expect(await db.expenses.count()).toBe(0);
    expect(TestBed.inject(Router).url).toBe('/login');
    expect(await setUp().restore()).toBeFalse();
  });

  it('warns before signing out with unsynced changes', async () => {
    const auth = await signInThandi();
    goOffline();
    await addOfflineExpense();

    expect(await auth.signOut(decline)).toBeFalse();
    expect(auth.signedIn()).toBeTrue();
    expect(await db.outbox.count()).toBe(1);

    const confirmLoss = jasmine.createSpy('confirmLoss').and.callFake(accept);
    expect(await auth.signOut(confirmLoss)).toBeTrue();
    expect(confirmLoss).toHaveBeenCalledWith(1);
    expect(await db.outbox.count()).toBe(0);
  });

  it('signs out even when the server cannot be reached', async () => {
    const auth = setUp();
    await auth.signIn(thandi, accept);
    api.failWith = new ApiError('network', 0, 'offline');

    expect(await auth.signOut(accept)).toBeTrue();
    expect(auth.signedIn()).toBeFalse();
  });

  it('re-authenticates the same user and resumes syncing', async () => {
    const auth = setUp();
    await auth.signIn(thandi, accept);
    const syncNow = spyOn(TestBed.inject(SyncEngine), 'syncNow').and.resolveTo(true);

    await auth.reauthenticate('secret1');

    expect(api.signIns.at(-1)?.username).toBe('thandi@farm.test');
    expect(syncNow).toHaveBeenCalled();
  });

  it('derives permissions from the cached profile', async () => {
    api.addAccount({ ...OTHER_USER, farmOwner: false, roles: ['ROLE_USER'] });
    const auth = setUp();
    await auth.signIn({ email: OTHER_USER.email, password: 'secret1', rememberMe: true }, accept);
    expect(auth.can('FARM_MANAGER')).toBeFalse();
    expect(auth.canManageFarm()).toBeFalse();
  });
});

describe('safeReturnUrl', () => {
  it('only allows same-app paths', () => {
    expect(safeReturnUrl('/expenses?action=new')).toBe('/expenses?action=new');
    expect(safeReturnUrl('//evil.example')).toBe('/dashboard');
    expect(safeReturnUrl('https://evil.example')).toBe('/dashboard');
    expect(safeReturnUrl('/login')).toBe('/dashboard');
    expect(safeReturnUrl(null)).toBe('/dashboard');
  });
});
