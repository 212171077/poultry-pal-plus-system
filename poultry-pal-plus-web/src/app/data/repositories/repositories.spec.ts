import { TestBed } from '@angular/core/testing';
import { AppDb } from '../db/app-db';
import { FakeSyncServer, createTestDb, provideTestDb } from '../testing/fake-sync-server';
import { SyncApi } from '../sync/sync-api';
import { SyncEngine } from '../sync/sync-engine';
import { SyncQueue } from '../sync/sync-queue';
import { CoopRepository, EggRecordRepository, ExpenseRepository } from './repositories';

const server = () => TestBed.inject(FakeSyncServer);

describe('Repositories (local-first writes)', () => {
  let db: AppDb;
  let expenses: ExpenseRepository;

  const expense = {
    coopId: 'coop-1',
    expenseDate: '2026-01-10T00:00:00.000Z',
    expenseType: 'Feed Costs',
    amount: 120,
  };

  beforeEach(async () => {
    db = createTestDb();
    TestBed.configureTestingModule({
      providers: [
        provideTestDb(db),
        { provide: FakeSyncServer, useValue: new FakeSyncServer() },
        { provide: SyncApi, useExisting: FakeSyncServer },
      ],
    });
    expenses = TestBed.inject(ExpenseRepository);
    await TestBed.inject(SyncEngine).sync();
  });

  afterEach(async () => {
    await db.delete();
  });

  it('stores the record and its outbox operation together', async () => {
    const created = await expenses.create(expense);

    const [op] = await db.outbox.toArray();
    expect(op).toEqual(
      jasmine.objectContaining({
        entityType: 'EXPENSE',
        operation: 'UPSERT',
        entityId: created.id,
        coopId: 'coop-1',
        baseVersion: null,
        status: 'pending',
      }),
    );
    expect(op.payload).toEqual(
      jasmine.objectContaining({ amount: 120, expenseType: 'Feed Costs' }),
    );
  });

  it('writes nothing when validation fails', async () => {
    await expectAsync(expenses.create({ ...expense, coopId: 'missing' })).toBeRejectedWithError(
      /coop/,
    );
    expect(await db.expenses.count()).toBe(0);
    expect(await db.outbox.count()).toBe(0);
  });

  it('drops a record created and deleted before it was ever sent', async () => {
    const created = await expenses.create(expense);
    await expenses.remove(created.id);

    expect(await db.expenses.count()).toBe(0);
    expect(await db.outbox.count()).toBe(0);
  });

  it('bases edits of synced records on the server version', async () => {
    const created = await expenses.create(expense);
    await TestBed.inject(SyncEngine).sync();
    const synced = (await expenses.get(created.id))!;

    await expenses.update(created.id, { amount: 99 });
    await expenses.remove(created.id);

    const ops = await db.outbox.toArray();
    expect(ops.length).toBe(1);
    expect(ops[0]).toEqual(
      jasmine.objectContaining({ operation: 'DELETE', baseVersion: synced.version }),
    );
  });

  it('computes derived totals before the server does', async () => {
    const eggs = TestBed.inject(EggRecordRepository);
    const record = await eggs.create({
      coopId: 'coop-1',
      createdDate: '2026-01-10T00:00:00.000Z',
      boxSize: '30 eggs box',
      numberOfBoxes: 3,
    });
    expect(record.totalEggs).toBe(90);
  });

  it('lists coops by name', async () => {
    const coops = TestBed.inject(CoopRepository);
    expect((await coops.listSorted()).map((coop) => coop.coopName)).toEqual(['Layer House A']);
  });

  describe('coop lifecycle', () => {
    let coops: CoopRepository;
    const sync = () => TestBed.inject(SyncEngine).sync();
    const batch = {
      coopName: 'Layer House A',
      coopType: 'LAYERS' as const,
      growthPhase: 'BROODING_PHASE' as const,
      numberOfChickens: 300,
      chickenArrivalDate: '2026-02-01T00:00:00.000Z',
    };

    beforeEach(() => {
      coops = TestBed.inject(CoopRepository);
    });

    it('starts a new batch: archives records locally and on the server', async () => {
      const synced = await expenses.create(expense);
      await sync();
      const offline = await expenses.create({ ...expense, amount: 5 });

      await coops.startNewBatch('coop-1', batch);

      expect(await db.expenses.count()).toBe(0);
      expect((await coops.get('coop-1'))?.numberOfChickens).toBe(300);
      const ops = await db.outbox.toArray();
      expect(ops.map((op) => op.operation)).toEqual(['UPSERT', 'ACTION']);

      await sync();

      expect(await db.outbox.count()).toBe(0);
      expect(await db.expenses.count()).toBe(0);
      expect(server().get('EXPENSE', synced.id)).toBeNull();
      expect(server().get('EXPENSE', offline.id)).toBeNull();
      expect(server().get('COOP', 'coop-1')?.['numberOfChickens']).toBe(300);
      expect((await coops.get('coop-1'))?.syncStatus).toBe('synced');
    });

    it('moves a flock and its records into an empty coop of the same type', async () => {
      const grower = await coops.create({ ...batch, coopName: 'Grower', numberOfChickens: 0 });
      const record = await expenses.create(expense);
      await sync();

      await coops.transitionPhase('coop-1', 'GROWING_REARING_PHASE', grower.id);

      expect((await expenses.get(record.id))?.coopId).toBe(grower.id);
      expect((await coops.get(grower.id))?.numberOfChickens).toBe(500);
      expect((await coops.get('coop-1'))?.numberOfChickens).toBe(0);

      await sync();

      expect(server().get('EXPENSE', record.id)?.['coopId']).toBe(grower.id);
      expect(server().get('COOP', grower.id)?.['growthPhase']).toBe('GROWING_REARING_PHASE');
      expect((await coops.get('coop-1'))?.growthPhase).toBe('BROODING_PHASE');
    });

    it('refuses to move a flock into a coop that still has chickens', async () => {
      const busy = await coops.create({ ...batch, coopName: 'Busy' });
      await expectAsync(
        coops.transitionPhase('coop-1', 'GROWING_REARING_PHASE', busy.id),
      ).toBeRejectedWithError(/still has chickens/);
      expect(await db.outbox.filter((op) => op.operation === 'ACTION').count()).toBe(0);
    });

    it('re-downloads the farm when a coop action is discarded', async () => {
      await expenses.create(expense);
      await sync();
      await coops.startNewBatch('coop-1', batch);
      const [action] = await db.outbox.toArray();

      await TestBed.inject(SyncQueue).discard(action.opId);
      await sync();

      expect(await db.expenses.count()).toBe(1);
      expect((await coops.get('coop-1'))?.numberOfChickens).toBe(500);
    });

    it('deletes a coop with its records', async () => {
      const coop = await coops.create({ ...batch, coopName: 'Temp' });
      await expenses.create({ ...expense, coopId: coop.id });

      await coops.remove(coop.id);

      expect(await db.expenses.count()).toBe(0);
      expect(await db.outbox.count()).toBe(0);
    });
  });
});
