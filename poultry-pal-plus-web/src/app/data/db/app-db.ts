import { InjectionToken } from '@angular/core';
import Dexie, { Table } from 'dexie';
import {
  LocalCoop,
  LocalEggRecord,
  LocalExpense,
  LocalFarm,
  LocalMortality,
  LocalReminder,
  LocalSale,
  LocalSettings,
  LocalUser,
  OutboxOperation,
  ProductionCacheEntry,
  ReportRequest,
  SyncConflict,
  SyncMetaEntry,
} from '../models/local';

export const DEFAULT_DB_NAME = 'poultry-pal';

/**
 * The offline database. Every screen reads from here; only the sync engine talks to the server.
 *
 * Schema migrations: never edit a released `version(n)` block. Add `version(n + 1).stores({...})`
 * with only the changed tables, plus an `.upgrade(tx => ...)` callback when existing rows need
 * reshaping. Dexie runs the steps in order when an older database opens. If a change cannot be
 * migrated, clear the entity tables and the `cursor` in `syncMeta` in the upgrade so the next sync
 * re-bootstraps from the server — never clear `outbox`, which holds unsynced user work.
 */
export class AppDb extends Dexie {
  farms!: Table<LocalFarm, string>;
  coops!: Table<LocalCoop, string>;
  sales!: Table<LocalSale, string>;
  mortalities!: Table<LocalMortality, string>;
  expenses!: Table<LocalExpense, string>;
  eggRecords!: Table<LocalEggRecord, string>;
  reminders!: Table<LocalReminder, string>;
  users!: Table<LocalUser, string>;
  settings!: Table<LocalSettings, string>;
  outbox!: Table<OutboxOperation, number>;
  syncMeta!: Table<SyncMetaEntry, string>;
  conflicts!: Table<SyncConflict, string>;
  reportRequests!: Table<ReportRequest, string>;
  productionCache!: Table<ProductionCacheEntry, string>;

  constructor(name = DEFAULT_DB_NAME) {
    super(name);
    this.version(1).stores({
      farms: 'id',
      coops: 'id, syncStatus, coopType',
      sales: 'id, coopId, saleDate, syncStatus',
      mortalities: 'id, coopId, dateOccurred, syncStatus',
      expenses: 'id, coopId, expenseDate, syncStatus',
      eggRecords: 'id, coopId, createdDate, syncStatus',
      reminders: 'id, coopId, dueDate, reminderType, syncStatus',
      users: 'id, farmId',
      settings: 'userId, farmId',
      outbox: '++seq, &opId, status, [entityType+entityId], coopId',
      syncMeta: 'key',
      conflicts: 'opId, [entityType+entityId]',
    });
    this.version(2).stores({
      reportRequests: 'id, status, createdAt',
    });
    this.version(3).stores({
      productionCache: 'key',
    });
  }

  /** Tables holding farm data downloaded from the server (everything except sync bookkeeping). */
  get entityTables(): Table[] {
    return [
      this.farms,
      this.coops,
      this.sales,
      this.mortalities,
      this.expenses,
      this.eggRecords,
      this.reminders,
      this.users,
      this.settings,
    ];
  }
}

export const APP_DB = new InjectionToken<AppDb>('APP_DB', {
  providedIn: 'root',
  factory: () => new AppDb(),
});
