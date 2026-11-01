import { Signal, inject } from '@angular/core';
import { APP_DB } from '../db/app-db';
import { liveSignal } from '../db/live-signal';
import { SyncedRecord } from '../models/local';
import { EntityDef, newId } from '../sync/entities';
import { SyncQueue } from '../sync/sync-queue';

/** Fields a caller supplies when creating a record; sync bookkeeping is filled in here. */
export type NewRecord<T extends SyncedRecord> = Omit<
  T,
  'id' | 'version' | 'syncStatus' | 'updatedAt' | 'updatedBy'
>;

/** Fields a caller may change. */
export type RecordChanges<T extends SyncedRecord> = Partial<NewRecord<T>>;

/**
 * Local-first repository: reads come from IndexedDB, and every write is a command that stores the
 * record and its outbox operation in one transaction, so neither can exist without the other.
 */
export abstract class RecordRepository<T extends SyncedRecord> {
  protected readonly db = inject(APP_DB);
  protected readonly queue = inject(SyncQueue);
  protected abstract readonly def: EntityDef<T>;

  get(id: string): Promise<T | undefined> {
    return this.def.table(this.db).get(id);
  }

  list(): Promise<T[]> {
    return this.def.table(this.db).toArray();
  }

  /** Live list of all records. Call in an injection context (e.g. a component field). */
  watchAll(): Signal<T[] | undefined> {
    return liveSignal(() => this.list());
  }

  async create(input: NewRecord<T>): Promise<T> {
    const table = this.def.table(this.db);
    const record = this.derive({
      ...input,
      id: newId(),
      version: null,
      syncStatus: 'pending',
    } as unknown as T);
    await this.db.transaction('rw', [table, this.db.coops, this.db.outbox], async () => {
      await this.validate(record);
      await table.add(record);
      await this.queue.enqueue({
        def: this.def as unknown as EntityDef,
        operation: 'UPSERT',
        record,
        before: null,
        fields: this.def.payloadFields,
      });
    });
    this.queue.notify();
    return record;
  }

  async update(id: string, changes: RecordChanges<T>): Promise<T> {
    const table = this.def.table(this.db);
    let updated!: T;
    await this.db.transaction('rw', [table, this.db.coops, this.db.outbox], async () => {
      const current = await table.get(id);
      if (!current) throw new Error(`${this.def.noun} not found`);
      const syncStatus = current.syncStatus === 'synced' ? 'pending' : current.syncStatus;
      updated = this.derive({ ...current, ...changes, id, syncStatus } as T);
      await this.validate(updated);
      await table.put(updated);
      await this.queue.enqueue({
        def: this.def as unknown as EntityDef,
        operation: 'UPSERT',
        record: updated,
        before: current,
        fields: Object.keys(changes).filter((field) => this.def.payloadFields.includes(field)),
      });
    });
    this.queue.notify();
    return updated;
  }

  async remove(id: string): Promise<void> {
    const table = this.def.table(this.db);
    await this.db.transaction('rw', [table, this.db.outbox], async () => {
      const current = await table.get(id);
      if (!current) return;
      await table.delete(id);
      await this.queue.enqueue({
        def: this.def as unknown as EntityDef,
        operation: 'DELETE',
        record: current,
        before: current,
        fields: [],
      });
    });
    this.queue.notify();
  }

  /** Computes server-derived fields (totals) so the UI shows them before the record syncs. */
  protected derive(record: T): T {
    return record;
  }

  /** Throws when the record cannot be saved. Runs inside the write transaction. */
  protected validate(record: T): Promise<void> {
    void record;
    return Promise.resolve();
  }
}

/** Repository for records that belong to a coop (sales, mortality, expenses, egg packaging). */
export abstract class CoopChildRepository<
  T extends SyncedRecord & { readonly coopId: string },
> extends RecordRepository<T> {
  listByCoop(coopId: string): Promise<T[]> {
    return this.def.table(this.db).where('coopId').equals(coopId).toArray();
  }

  protected override async validate(record: T): Promise<void> {
    if (!(await this.db.coops.get(record.coopId))) {
      throw new Error('Choose a coop that exists on this device');
    }
  }
}
