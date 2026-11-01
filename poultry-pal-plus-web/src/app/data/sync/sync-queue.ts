import { Injectable, inject } from '@angular/core';
import { APP_DB } from '../db/app-db';
import { OutboxOperation, SyncedRecord } from '../models/local';
import { CoopActionPayload, SyncEntityType, SyncOperationType } from '../models/sync-api';
import { EntityDef, entityDef, fromServer, newId, recordKey, toPayload } from './entities';
import { applyServerRecord, pendingKeys, setMeta } from './local-store';

/** Listener notified after a local change was queued (the sync engine uses it to push soon). */
export type QueueListener = () => void;

export interface EnqueueRequest {
  readonly def: EntityDef;
  readonly operation: Extract<SyncOperationType, 'UPSERT' | 'DELETE'>;
  /** The record after the change (or the deleted record for DELETE). */
  readonly record: SyncedRecord & { readonly coopId?: string };
  /** The record before the change; `null` for creates. */
  readonly before: (SyncedRecord & { readonly coopId?: string }) | null;
  /** Payload fields the user changed. */
  readonly fields: readonly string[];
}

/**
 * The outbox: every local change is stored as an operation and pushed in FIFO order. Changes to a
 * record that has not been sent yet are coalesced into its queued operation, so editing a record five
 * times offline sends one UPSERT, and creating then deleting it sends nothing.
 */
@Injectable({ providedIn: 'root' })
export class SyncQueue {
  private readonly db = inject(APP_DB);
  private readonly listeners = new Set<QueueListener>();

  onEnqueue(listener: QueueListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /** Notifies listeners; call after the transaction that enqueued work has committed. */
  notify(): void {
    this.listeners.forEach((listener) => listener());
  }

  /** Must run inside a `rw` transaction that includes the record's table and `outbox`. */
  async enqueue(request: EnqueueRequest): Promise<void> {
    const { def, operation, record, before, fields } = request;
    const db = this.db;
    const queued = await this.opsFor(def.type, record.id);
    const last = queued.at(-1);
    const coalescable = last?.status === 'pending' && last.attempts === 0 && last.seq !== undefined;

    if (coalescable && last.operation === 'UPSERT') {
      if (operation === 'UPSERT') {
        await db.outbox.update(last.seq!, {
          payload: toPayload(def, record),
          fields: [...new Set([...last.fields, ...fields])],
          label: def.describe(record as never),
        });
        return;
      }
      // Created offline and deleted before it ever reached the server: nothing to send.
      if (last.baseVersion === null && record.version === null && queued.length === 1) {
        await db.outbox.delete(last.seq!);
        return;
      }
      await db.outbox.delete(last.seq!);
      await db.outbox.add(
        this.operation(def, 'DELETE', record, last.baseVersion, last.baseRecord ?? null, []),
      );
      return;
    }

    const baseRecord =
      before && (before.syncStatus === 'synced' || queued.length === 0)
        ? (before as unknown as Record<string, unknown>)
        : null;
    await db.outbox.add(
      this.operation(def, operation, record, record.version ?? null, baseRecord, fields),
    );
  }

  /** Queues a reminder action (mark done / not applicable). Runs inside a transaction. */
  async enqueueReminderAction(
    reminderId: string,
    coopId: string,
    payload: Record<string, unknown>,
    label: string,
  ): Promise<void> {
    await this.db.outbox.add({
      opId: newId(),
      entityType: 'REMINDER',
      operation: 'ACTION',
      entityId: reminderId,
      coopId,
      baseVersion: null,
      payload,
      status: 'pending',
      attempts: 0,
      fields: [],
      baseRecord: null,
      label,
      createdAt: new Date().toISOString(),
    });
  }

  /**
   * Queues a coop lifecycle action (new batch, phase transition). Runs inside a transaction. Actions
   * are never coalesced and carry no base version: the server applies them to its current copy.
   */
  async enqueueCoopAction(
    coopId: string,
    payload: CoopActionPayload,
    label: string,
  ): Promise<void> {
    await this.db.outbox.add({
      opId: newId(),
      entityType: 'COOP',
      operation: 'ACTION',
      entityId: coopId,
      coopId,
      baseVersion: null,
      payload,
      status: 'pending',
      attempts: 0,
      fields: [],
      baseRecord: null,
      label,
      createdAt: new Date().toISOString(),
    });
  }

  /** Re-queues a failed operation unchanged (e.g. after the user fixed access rights). */
  async retry(opId: string): Promise<void> {
    await this.db.transaction('rw', this.db.tables, async () => {
      const op = await this.db.outbox.where('opId').equals(opId).first();
      if (!op?.seq) return;
      await this.db.outbox.update(op.seq, {
        status: 'pending',
        lastError: null,
        errorCode: null,
        errors: null,
      });
      await this.setRecordStatus(op.entityType, op.entityId, 'pending');
    });
    this.notify();
  }

  /**
   * Drops a failed or conflicting operation and every later change to the same record, restoring the
   * last synced copy (or removing a record that never reached the server).
   */
  async discard(opId: string): Promise<void> {
    let redownload = false;
    await this.db.transaction('rw', this.db.tables, async () => {
      const op = await this.db.outbox.where('opId').equals(opId).first();
      if (!op) return;
      await this.dropFrom(op);
      await this.db.conflicts.delete(opId);
      const def = entityDef(op.entityType);
      if (!def) return;
      if (op.entityType === 'COOP' && op.operation === 'ACTION') {
        // A coop action changed several records locally; re-download the farm to undo it.
        await setMeta(this.db, 'cursor', null);
        redownload = true;
        return;
      }
      if (op.baseRecord) {
        await def.table(this.db).put({ ...op.baseRecord, syncStatus: 'synced' } as SyncedRecord);
      } else if (op.operation === 'UPSERT' && op.baseVersion === null) {
        await def.table(this.db).delete(op.entityId);
      }
    });
    if (redownload) this.notify();
  }

  /** Conflict resolution: re-send the user's version on top of the server's current version. */
  async keepMine(opId: string): Promise<void> {
    await this.db.transaction('rw', this.db.tables, async () => {
      const conflict = await this.db.conflicts.get(opId);
      const op = await this.db.outbox.where('opId').equals(opId).first();
      if (!op?.seq) return;
      const server = conflict?.server ?? null;
      const def = entityDef(op.entityType);
      if (op.operation === 'DELETE' && !server) {
        await this.db.outbox.delete(op.seq);
      } else {
        const version = typeof server?.['version'] === 'number' ? server['version'] : null;
        await this.db.outbox.update(op.seq, {
          // A new opId: the server remembers the result of the old one.
          opId: newId(),
          status: 'pending',
          baseVersion: version,
          baseRecord: def && server ? toRecordMap(fromServer(def, server)) : null,
          lastError: null,
          errorCode: null,
          errors: null,
        });
        await this.setRecordStatus(op.entityType, op.entityId, 'pending');
      }
      await this.db.conflicts.delete(opId);
    });
    this.notify();
  }

  /** Conflict resolution: accept the server's copy and drop the local change. */
  async useServer(opId: string): Promise<void> {
    await this.db.transaction('rw', this.db.tables, async () => {
      const conflict = await this.db.conflicts.get(opId);
      const op = await this.db.outbox.where('opId').equals(opId).first();
      if (op) await this.dropFrom(op);
      await this.db.conflicts.delete(opId);
      const target = conflict ?? op;
      if (!target) return;
      if (conflict?.server) {
        await applyServerRecord(
          this.db,
          target.entityType,
          conflict.server,
          await pendingKeys(this.db),
        );
      } else {
        await entityDef(target.entityType)?.table(this.db).delete(target.entityId);
      }
    });
  }

  async opsFor(type: SyncEntityType, id: string): Promise<OutboxOperation[]> {
    return this.db.outbox.where('[entityType+entityId]').equals([type, id]).sortBy('seq');
  }

  async setRecordStatus(
    type: SyncEntityType,
    id: string,
    syncStatus: SyncedRecord['syncStatus'],
  ): Promise<void> {
    if (type === 'REMINDER') {
      await this.db.reminders.update(id, { syncStatus });
      return;
    }
    await entityDef(type)?.table(this.db).update(id, { syncStatus });
  }

  private async dropFrom(op: OutboxOperation): Promise<void> {
    const later = (await this.opsFor(op.entityType, op.entityId)).filter(
      (other) => (other.seq ?? 0) >= (op.seq ?? 0),
    );
    await this.db.outbox.bulkDelete(later.map((other) => other.seq!));
  }

  private operation(
    def: EntityDef,
    operation: Extract<SyncOperationType, 'UPSERT' | 'DELETE'>,
    record: SyncedRecord & { readonly coopId?: string },
    baseVersion: number | null,
    baseRecord: Record<string, unknown> | null,
    fields: readonly string[],
  ): OutboxOperation {
    return {
      opId: newId(),
      entityType: def.type,
      operation,
      entityId: record.id,
      coopId: def.type === 'COOP' ? record.id : (record.coopId ?? null),
      baseVersion,
      payload: operation === 'UPSERT' ? toPayload(def, record) : null,
      status: 'pending',
      attempts: 0,
      fields: operation === 'UPSERT' ? fields : [],
      baseRecord,
      label: def.describe(record as never),
      createdAt: new Date().toISOString(),
    };
  }
}

function toRecordMap(record: object): Record<string, unknown> {
  return record as Record<string, unknown>;
}

/** Key used to keep later operations on a record behind an unresolved earlier one. */
export function opKey(op: Pick<OutboxOperation, 'entityType' | 'entityId'>): string {
  return recordKey(op.entityType, op.entityId);
}
