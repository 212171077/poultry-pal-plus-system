import { TestBed } from '@angular/core/testing';
import { SyncStatusService } from '../../core/sync/sync-status.service';
import { AppDb } from '../db/app-db';
import { ExpenseRepository } from '../repositories/repositories';
import {
  FakeSyncServer,
  createTestDb,
  provideFakeSyncServer,
  provideTestDb,
} from '../testing/fake-sync-server';
import { applyChanges, getMeta } from './local-store';
import { SyncHttpError } from './sync-api';
import { SyncEngine } from './sync-engine';
import { SyncQueue } from './sync-queue';

describe('SyncEngine', () => {
  let db: AppDb;
  let server: FakeSyncServer;
  let engine: SyncEngine;
  let expenses: ExpenseRepository;

  const newExpense = (amount = 120, additionalInfo = 'Layer mash') => ({
    coopId: 'coop-1',
    expenseDate: '2026-01-10T00:00:00.000Z',
    expenseType: 'Feed Costs',
    amount,
    additionalInfo,
  });

  beforeEach(async () => {
    db = createTestDb();
    server = new FakeSyncServer();
    TestBed.configureTestingModule({
      providers: [provideTestDb(db), provideFakeSyncServer(server)],
    });
    engine = TestBed.inject(SyncEngine);
    expenses = TestBed.inject(ExpenseRepository);
    expect(await engine.sync()).toBeTrue();
  });

  afterEach(async () => {
    await db.delete();
  });

  it('bootstraps a fresh device with farm data, user and cursor', async () => {
    expect((await db.coops.toArray()).map((coop) => coop.coopName)).toEqual(['Layer House A']);
    expect(await db.farms.count()).toBe(1);
    expect((await db.users.toArray())[0].current).toBeTrue();
    expect((await db.settings.toArray())[0].currency).toBe('ZAR');
    expect(await getMeta(db, 'cursor')).toBe(server.version);
  });

  it('pushes records created offline and marks them synced', async () => {
    const created = await expenses.create(newExpense());
    expect(created.syncStatus).toBe('pending');
    expect(await db.outbox.count()).toBe(1);

    expect(await engine.sync()).toBeTrue();

    const saved = await expenses.get(created.id);
    expect(saved?.syncStatus).toBe('synced');
    expect(saved?.version).toEqual(jasmine.any(Number));
    expect(await db.outbox.count()).toBe(0);
    expect(server.get('EXPENSE', created.id)?.['amount']).toBe(120);
  });

  it('sends one operation for a record edited several times offline', async () => {
    const created = await expenses.create(newExpense());
    await expenses.update(created.id, { amount: 130 });
    await expenses.update(created.id, { additionalInfo: 'Grower pellets' });

    await engine.sync();

    expect(server.pushed.flat().length).toBe(1);
    expect(server.get('EXPENSE', created.id)).toEqual(
      jasmine.objectContaining({ amount: 130, additionalInfo: 'Grower pellets' }),
    );
  });

  it('marks rejected operations as failed and keeps later changes queued', async () => {
    const created = await expenses.create(newExpense(-5));

    expect(await engine.sync()).toBeTrue();

    const [op] = await db.outbox.toArray();
    expect(op.status).toBe('failed');
    expect(op.errors).toEqual(['amount: must be greater than or equal to 0']);
    expect((await expenses.get(created.id))?.syncStatus).toBe('failed');

    await expenses.update(created.id, { amount: 5 });
    await engine.sync();
    expect(server.get('EXPENSE', created.id)).toBeNull();

    await TestBed.inject(SyncQueue).discard(op.opId);
    expect(await expenses.get(created.id)).toBeUndefined();
    expect(await db.outbox.count()).toBe(0);
  });

  it('merges changes to different fields made on two devices', async () => {
    const created = await expenses.create(newExpense());
    await engine.sync();

    server.put('EXPENSE', created.id, 'coop-1', { amount: 999 });
    await expenses.update(created.id, { additionalInfo: 'Edited offline' });
    expect(await engine.sync()).toBeTrue();

    expect(server.get('EXPENSE', created.id)).toEqual(
      jasmine.objectContaining({ amount: 999, additionalInfo: 'Edited offline' }),
    );
    const local = await expenses.get(created.id);
    expect(local).toEqual(
      jasmine.objectContaining({
        amount: 999,
        additionalInfo: 'Edited offline',
        syncStatus: 'synced',
      }),
    );
    expect(await db.conflicts.count()).toBe(0);
  });

  it('asks the user when both devices changed the same field', async () => {
    const created = await expenses.create(newExpense());
    await engine.sync();

    server.put('EXPENSE', created.id, 'coop-1', { amount: 999 });
    await expenses.update(created.id, { amount: 150 });
    await engine.sync();

    const [conflict] = await db.conflicts.toArray();
    expect(conflict.fields).toEqual(['amount']);
    expect(conflict.server?.['amount']).toBe(999);
    expect((await expenses.get(created.id))?.syncStatus).toBe('conflict');

    await TestBed.inject(SyncQueue).keepMine(conflict.opId);
    await engine.sync();

    expect(server.get('EXPENSE', created.id)?.['amount']).toBe(150);
    expect((await expenses.get(created.id))?.syncStatus).toBe('synced');
    expect(await db.conflicts.count()).toBe(0);
  });

  it('can resolve a conflict with the server version', async () => {
    const created = await expenses.create(newExpense());
    await engine.sync();
    server.put('EXPENSE', created.id, 'coop-1', { amount: 999 });
    await expenses.update(created.id, { amount: 150 });
    await engine.sync();

    const [conflict] = await db.conflicts.toArray();
    await TestBed.inject(SyncQueue).useServer(conflict.opId);

    expect(await expenses.get(created.id)).toEqual(
      jasmine.objectContaining({ amount: 999, syncStatus: 'synced' }),
    );
    expect(await db.outbox.count()).toBe(0);
  });

  it('pulls changes and deletions made on other devices', async () => {
    const created = await expenses.create(newExpense());
    await engine.sync();

    server.put('EXPENSE', 'remote-1', 'coop-1', {
      expenseDate: '2026-01-11T00:00:00.000Z',
      expenseType: 'Labor Costs',
      amount: 450,
    });
    server.remove('EXPENSE', created.id);
    await engine.sync();

    expect((await expenses.list()).map((expense) => expense.id)).toEqual(['remote-1']);
  });

  it('never overwrites a record that has unsynced local changes', async () => {
    const created = await expenses.create(newExpense());
    await engine.sync();
    await expenses.update(created.id, { amount: 1 });

    await db.transaction('rw', db.tables, () =>
      applyChanges(db, {
        cursor: 999,
        hasMore: false,
        resetRequired: false,
        expenses: [{ id: created.id, coopId: 'coop-1', amount: 777, version: 50 }],
        tombstones: [{ entityType: 'EXPENSE', entityId: created.id }],
      }),
    );

    expect((await expenses.get(created.id))?.amount).toBe(1);
  });

  it('keeps operations queued while the server is unreachable', async () => {
    await expenses.create(newExpense());
    server.failWith = { error: new SyncHttpError('network', 0, 'offline') };

    expect(await engine.sync()).toBeFalse();
    expect((await db.outbox.toArray())[0].status).toBe('pending');

    // syncNow also cancels the scheduled backoff retry.
    expect(await engine.syncNow()).toBeTrue();
    expect(await db.outbox.count()).toBe(0);
  });

  it('refreshes an expired session once and retries', async () => {
    await expenses.create(newExpense());
    server.failWith = { error: new SyncHttpError('auth', 401, 'expired'), sticky: true };

    expect(await engine.sync()).toBeTrue();
    expect(server.refreshCalls).toBe(1);
    expect(await db.outbox.count()).toBe(0);
  });

  it('pauses and asks the user to sign in when the refresh fails', async () => {
    await expenses.create(newExpense());
    server.failWith = { error: new SyncHttpError('auth', 401, 'expired'), sticky: true };
    server.refreshFails = true;

    expect(await engine.sync()).toBeFalse();
    expect(TestBed.inject(SyncStatusService).state()).toBe('auth-required');
    expect(await db.outbox.count()).toBe(1);

    // Paused: background syncs do nothing until the user signs in or presses "Sync now".
    server.failWith = null;
    expect(await engine.sync()).toBeFalse();
    expect(await engine.syncNow()).toBeTrue();
  });
});
