import { Provider } from '@angular/core';
import type { ProductionSnapshot } from '../../features/production/production-api';
import { AppDb, APP_DB } from '../db/app-db';
import {
  SyncBootstrapResponse,
  SyncChangesResponse,
  SyncOperationDto,
  SyncOperationResult,
  SyncPushResponse,
  SyncTombstone,
  UserInfo,
} from '../models/sync-api';
import { SyncApi, SyncHttpError } from '../sync/sync-api';

const LIST_KEYS = {
  COOP: 'coops',
  SALE: 'sales',
  MORTALITY: 'mortalities',
  EXPENSE: 'expenses',
  EGG_PACKAGING: 'eggPackagingRecords',
} as const;

type ListType = keyof typeof LIST_KEYS;

interface StoredRecord {
  type: ListType;
  id: string;
  coopId: string;
  version: number;
  deleted: boolean;
  data: Record<string, unknown>;
}

export const TEST_USER: UserInfo = {
  id: 'user-1',
  name: 'Thandi',
  surname: 'Mokoena',
  email: 'thandi@farm.test',
  farmId: 'farm-1',
  farmOwner: true,
  active: true,
};

/**
 * In-memory implementation of the backend sync contract (opId idempotency, optimistic versions,
 * tombstones) for unit tests. Tests can edit records "from another device" and inject failures.
 */
export class FakeSyncServer implements Pick<
  SyncApi,
  'push' | 'changes' | 'bootstrap' | 'refresh' | 'productionSnapshot'
> {
  version = 0;
  readonly records = new Map<string, StoredRecord>();
  readonly results = new Map<string, SyncOperationResult>();
  readonly pushed: SyncOperationDto[][] = [];
  /** When set, calls fail with this error (cleared after one call unless `sticky`). */
  failWith: { error: SyncHttpError; sticky?: boolean } | null = null;
  /** Returned by `productionSnapshot`; `null` means the user has no production access. */
  productionSnapshotData: ProductionSnapshot | null = null;
  /** Decides the outcome of production commands; applies them by default. */
  productionHandler: ((op: SyncOperationDto) => SyncOperationResult) | null = null;
  refreshFails = false;
  refreshCalls = 0;

  constructor() {
    this.put('COOP', 'coop-1', 'coop-1', {
      coopName: 'Layer House A',
      coopType: 'LAYERS',
      growthPhase: 'PRODUCTION_FINISHING_PHASE',
      numberOfChickens: 500,
      active: true,
      reminder: { vaccines: [], feeds: [], medicines: [] },
    });
  }

  /** Writes a record as if another device changed it. Returns the new version. */
  put(type: ListType, id: string, coopId: string, fields: Record<string, unknown>): number {
    const key = `${type}:${id}`;
    const current = this.records.get(key);
    const version = ++this.version;
    const data: Record<string, unknown> = {
      ...(current && !current.deleted ? current.data : {}),
      ...fields,
      id,
      version,
    };
    if (type !== 'COOP') data['coopId'] = coopId;
    this.records.set(key, { type, id, coopId, version, deleted: false, data });
    return version;
  }

  remove(type: ListType, id: string): void {
    const record = this.records.get(`${type}:${id}`);
    if (record) {
      record.deleted = true;
      record.version = ++this.version;
    }
  }

  get(type: ListType, id: string): Record<string, unknown> | null {
    const record = this.records.get(`${type}:${id}`);
    return record && !record.deleted ? record.data : null;
  }

  async push(operations: readonly SyncOperationDto[]): Promise<SyncPushResponse> {
    this.maybeFail();
    this.pushed.push([...operations]);
    const results = operations.map((op) => {
      const replay = this.results.get(op.opId);
      if (replay) return { ...replay, duplicate: true };
      const result = this.apply(op);
      this.results.set(op.opId, result);
      return result;
    });
    return { results, serverVersion: this.version };
  }

  async changes(since: number): Promise<SyncChangesResponse> {
    this.maybeFail();
    return this.snapshot(since);
  }

  async bootstrap(): Promise<SyncBootstrapResponse> {
    this.maybeFail();
    return {
      user: TEST_USER,
      team: [TEST_USER],
      settings: { userId: TEST_USER.id, farmId: 'farm-1', currency: 'ZAR' },
      snapshot: this.snapshot(0),
    };
  }

  async productionSnapshot(): Promise<ProductionSnapshot> {
    this.maybeFail();
    if (!this.productionSnapshotData) throw new SyncHttpError('forbidden', 403, 'No access');
    return this.productionSnapshotData;
  }

  async refresh(): Promise<UserInfo> {
    this.refreshCalls++;
    if (this.refreshFails) throw new SyncHttpError('auth', 401, 'Refresh expired');
    this.failWith = null;
    return TEST_USER;
  }

  private maybeFail(): void {
    const failure = this.failWith;
    if (!failure) return;
    if (!failure.sticky) this.failWith = null;
    throw failure.error;
  }

  private snapshot(since: number): SyncChangesResponse {
    const lists: Record<string, Record<string, unknown>[]> = {
      coops: [],
      sales: [],
      mortalities: [],
      expenses: [],
      eggPackagingRecords: [],
    };
    const tombstones: SyncTombstone[] = [];
    for (const record of this.records.values()) {
      if (record.version <= since) continue;
      if (!record.deleted) {
        lists[LIST_KEYS[record.type]].push(record.data);
      } else if (since > 0) {
        tombstones.push({
          entityType: record.type,
          entityId: record.id,
          coopId: record.coopId,
          version: record.version,
        });
      }
    }
    return {
      cursor: this.version,
      hasMore: false,
      resetRequired: false,
      farm: since === 0 ? { id: 'farm-1', farmName: 'Sunrise Poultry', version: 1 } : null,
      ...lists,
      tombstones,
    };
  }

  private apply(op: SyncOperationDto): SyncOperationResult {
    const base = {
      opId: op.opId,
      entityType: op.entityType,
      entityId: op.entityId,
      coopId: op.coopId,
    };
    if (op.entityType === 'PRODUCTION') {
      return this.productionHandler
        ? this.productionHandler(op)
        : { ...base, status: 'APPLIED', serverRecord: { id: op.entityId } };
    }
    if (!(op.entityType in LIST_KEYS)) {
      return { ...base, status: 'REJECTED', errorCode: 'UNSUPPORTED', message: 'Not supported' };
    }
    if (op.operation === 'ACTION') return this.coopAction(op, base);
    const type = op.entityType as ListType;
    const current = this.records.get(`${type}:${op.entityId}`);
    const exists = !!current && !current.deleted;
    const conflict = (message: string): SyncOperationResult => ({
      ...base,
      status: 'CONFLICT',
      errorCode: 'VERSION_CONFLICT',
      message,
      version: current?.version ?? null,
      serverRecord: exists ? current.data : null,
    });

    if (op.operation === 'DELETE') {
      if (!exists) return { ...base, status: 'APPLIED', version: current?.version ?? null };
      if (op.baseVersion !== null && op.baseVersion !== current.version) {
        return conflict('Changed by someone else');
      }
      this.remove(type, op.entityId);
      return { ...base, status: 'APPLIED', version: this.version };
    }
    if (exists && op.baseVersion !== current.version) return conflict('Changed by someone else');
    if (!exists && op.baseVersion !== null) return conflict('Record no longer exists');
    if (type === 'EXPENSE' && Number(op.payload?.['amount']) < 0) {
      return {
        ...base,
        status: 'REJECTED',
        errorCode: 'VALIDATION',
        message: 'Validation failed',
        errors: ['amount: must be greater than or equal to 0'],
      };
    }
    const version = this.put(type, op.entityId, op.coopId ?? op.entityId, op.payload ?? {});
    return { ...base, status: 'APPLIED', version, serverRecord: this.get(type, op.entityId) };
  }

  /** `COOP` `ACTION`: new batch or phase transition, as in the backend `SyncService`. */
  private coopAction(
    op: SyncOperationDto,
    base: Pick<SyncOperationResult, 'opId' | 'entityType' | 'entityId' | 'coopId'>,
  ): SyncOperationResult {
    const coop = this.get('COOP', op.entityId);
    const rejected = (errorCode: string, message: string): SyncOperationResult => ({
      ...base,
      status: 'REJECTED',
      errorCode,
      message,
    });
    if (op.entityType !== 'COOP' || !coop) return rejected('NOT_FOUND', 'Coop not found');
    const payload = op.payload ?? {};
    const children = [...this.records.values()].filter(
      (record) => record.type !== 'COOP' && !record.deleted && record.coopId === op.entityId,
    );
    if (payload['action'] === 'NEW_BATCH') {
      children.forEach((record) => this.remove(record.type, record.id));
      this.put('COOP', op.entityId, op.entityId, payload['batch'] as Record<string, unknown>);
    } else {
      const phase = payload['newGrowthPhase'];
      const targetId = payload['targetCoopId'] as string | null;
      if (targetId && targetId !== op.entityId) {
        const target = this.get('COOP', targetId);
        if (!target) return rejected('NOT_FOUND', 'Target coop not found');
        if (Number(target['numberOfChickens']) > 0) {
          return rejected('VALIDATION', 'The target coop still has chickens');
        }
        this.put('COOP', targetId, targetId, {
          growthPhase: phase,
          numberOfChickens: coop['numberOfChickens'],
          chickenArrivalDate: coop['chickenArrivalDate'] ?? null,
        });
        children.forEach((record) => this.put(record.type, record.id, targetId, record.data));
        this.put('COOP', op.entityId, op.entityId, {
          growthPhase: 'BROODING_PHASE',
          numberOfChickens: 0,
          chickenArrivalDate: null,
        });
      } else {
        this.put('COOP', op.entityId, op.entityId, { growthPhase: phase });
      }
    }
    return {
      ...base,
      status: 'APPLIED',
      version: this.version,
      serverRecord: this.get('COOP', op.entityId),
    };
  }
}

let dbCounter = 0;

/** A fresh IndexedDB per test so specs never share state. Delete it in `afterEach`. */
export function createTestDb(): AppDb {
  return new AppDb(`pp-test-${Date.now()}-${dbCounter++}`);
}

export function provideTestDb(db: AppDb): Provider {
  return { provide: APP_DB, useValue: db };
}

export function provideFakeSyncServer(server: FakeSyncServer): Provider {
  return { provide: SyncApi, useValue: server };
}
