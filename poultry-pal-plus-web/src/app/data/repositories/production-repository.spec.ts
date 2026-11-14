import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { ConnectivityService } from '../../core/network/connectivity.service';
import { AppDb } from '../db/app-db';
import { SyncApi } from '../sync/sync-api';
import { FakeSyncServer, createTestDb, provideTestDb } from '../testing/fake-sync-server';
import { ProductionRepository } from './production-repository';

describe('ProductionRepository', () => {
  let db: AppDb;
  let repo: ProductionRepository;
  let online: boolean;

  beforeEach(() => {
    db = createTestDb();
    online = true;
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideTestDb(db),
        { provide: FakeSyncServer, useValue: new FakeSyncServer() },
        { provide: SyncApi, useExisting: FakeSyncServer },
        { provide: ConnectivityService, useValue: { online: () => online } },
      ],
    });
    repo = TestBed.inject(ProductionRepository);
  });

  afterEach(async () => {
    await db.delete();
  });

  const input = { equipmentId: 'inc-1', eggsSet: 100, plannedStartDate: '2026-02-01' };

  it('applies a command straight away when the server is reachable', async () => {
    const result = await repo.createBatch(input);

    expect(result).not.toBeNull();
    expect(await db.outbox.count()).toBe(0);
    const [[sent]] = TestBed.inject(FakeSyncServer).pushed;
    expect(sent.entityType).toBe('PRODUCTION');
    expect(sent.payload).toEqual({ command: 'BATCH_CREATE', body: input });
  });

  it('queues a command while offline', async () => {
    online = false;

    expect(await repo.createBatch(input)).toBeNull();

    const [op] = await db.outbox.toArray();
    expect(op).toEqual(
      jasmine.objectContaining({
        entityType: 'PRODUCTION',
        operation: 'ACTION',
        status: 'pending',
      }),
    );
    expect(TestBed.inject(FakeSyncServer).pushed.length).toBe(0);
  });

  it('queues behind earlier production changes', async () => {
    online = false;
    await repo.createBatch(input);
    online = true;

    expect(await repo.createBatch(input)).toBeNull();
    expect(await db.outbox.count()).toBe(2);
  });

  it('shows a rejected command as an error and queues nothing', async () => {
    TestBed.inject(FakeSyncServer).productionHandler = (op) => ({
      opId: op.opId,
      entityType: op.entityType,
      entityId: op.entityId,
      coopId: null,
      status: 'REJECTED',
      errorCode: 'CAPACITY_CONFLICT',
      message: 'Not enough hatcher capacity',
    });

    await expectAsync(repo.reserveCycle('b1', 'h1', 500)).toBeRejectedWith(
      jasmine.objectContaining({ kind: 'conflict', code: 'CAPACITY_CONFLICT' }),
    );
    expect(await db.outbox.count()).toBe(0);
  });
});
