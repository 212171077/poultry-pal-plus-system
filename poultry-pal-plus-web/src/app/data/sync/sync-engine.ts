import { ApplicationRef, DOCUMENT, Injectable, NgZone, inject, signal } from '@angular/core';
import { liveQuery } from 'dexie';
import { filter, first } from 'rxjs';
import { ConnectivityService } from '../../core/network/connectivity.service';
import { SyncStatusService } from '../../core/sync/sync-status.service';
import { APP_DB } from '../db/app-db';
import { OutboxOperation } from '../models/local';
import { SyncOperationDto, SyncOperationResult } from '../models/sync-api';
import { mergeConflict } from './conflict-merge';
import { entityDef, newId, recordKey } from './entities';
import {
  applyBootstrap,
  applyChanges,
  applyServerRecord,
  getMeta,
  pendingKeys,
  setMeta,
} from './local-store';
import { SyncApi, SyncHttpError } from './sync-api';
import { SyncQueue, opKey } from './sync-queue';

export const PUSH_BATCH_SIZE = 200;
export const PERIODIC_SYNC_MS = 60_000;
const MAX_BACKOFF_MS = 5 * 60_000;
const MAX_AUTO_MERGES = 5;
const LOCK_NAME = 'pp-sync';
const CHANNEL_NAME = 'pp-sync';

interface ChannelMessage {
  readonly type: 'state';
  readonly syncing: boolean;
  readonly authRequired: boolean;
}

/**
 * Moves data between IndexedDB and the server: pushes the outbox, then pulls changes since the last
 * cursor (or bootstraps a fresh device). Only one tab syncs at a time (Web Locks); others follow
 * through Dexie's cross-tab live queries and a BroadcastChannel for the syncing indicator.
 *
 * Triggers: app start, coming online, the tab becoming visible, local changes (debounced), a
 * periodic pull that doubles as the connectivity heartbeat, and "Sync now". Timers run outside
 * Angular's zone so they never keep the app "unstable" (which would block service-worker registration).
 */
@Injectable({ providedIn: 'root' })
export class SyncEngine {
  private readonly db = inject(APP_DB);
  private readonly api = inject(SyncApi);
  private readonly queue = inject(SyncQueue);
  private readonly status = inject(SyncStatusService);
  private readonly connectivity = inject(ConnectivityService);
  private readonly zone = inject(NgZone);
  private readonly appRef = inject(ApplicationRef);
  private readonly window = inject(DOCUMENT).defaultView;

  private readonly syncingState = signal(false);
  private readonly lastErrorState = signal<string | null>(null);
  readonly syncing = this.syncingState.asReadonly();
  /** Last problem that needs the user (permission or validation), shown in the Sync Center. */
  readonly lastError = this.lastErrorState.asReadonly();

  private started = false;
  private running: Promise<boolean> | null = null;
  private runAgain = false;
  private authPaused = false;
  private suspended = false;
  private backoffAttempt = 0;
  private debounceTimer: ReturnType<typeof setTimeout> | undefined;
  private retryTimer: ReturnType<typeof setTimeout> | undefined;
  private channel: BroadcastChannel | null = null;

  /** Starts background syncing once the app is stable. Safe to call more than once. */
  start(): void {
    if (this.started || !this.window) return;
    this.started = true;
    this.appRef.isStable
      .pipe(filter(Boolean), first())
      .subscribe(() => this.zone.runOutsideAngular(() => this.begin()));
  }

  /** Stops syncing while nobody is signed in on this device. Local data is left untouched. */
  suspend(): void {
    this.suspended = true;
    clearTimeout(this.debounceTimer);
    clearTimeout(this.retryTimer);
    this.status.report({ authRequired: false });
  }

  /** Resumes after a sign-in: clears any auth pause and syncs straight away. */
  resume(): Promise<boolean> {
    this.suspended = false;
    this.start();
    return this.syncNow();
  }

  /** Requests a sync soon (debounced), e.g. after a local change. */
  schedule(delayMs = 0): void {
    clearTimeout(this.debounceTimer);
    this.zone.runOutsideAngular(() => {
      this.debounceTimer = setTimeout(() => void this.sync(), delayMs);
    });
  }

  /** User-initiated sync: clears an auth pause and the backoff, then syncs immediately. */
  syncNow(): Promise<boolean> {
    this.authPaused = false;
    this.backoffAttempt = 0;
    clearTimeout(this.retryTimer);
    return this.sync();
  }

  /** Runs one full cycle unless one is already running. Resolves to `true` when fully synced. */
  sync(): Promise<boolean> {
    if (this.running) {
      this.runAgain = true;
      return this.running;
    }
    if (!this.connectivity.browserOnline() || this.authPaused || this.suspended) {
      return Promise.resolve(false);
    }
    this.running = this.withLock(() => this.cycle())
      .then((result) => result ?? false)
      .finally(() => {
        this.running = null;
        if (this.runAgain) {
          this.runAgain = false;
          this.schedule(0);
        }
      });
    return this.running;
  }

  /** Forgets the sync cursor so the next sync downloads a fresh copy (unsynced changes are kept). */
  async redownload(): Promise<boolean> {
    await setMeta(this.db, 'cursor', null);
    return this.syncNow();
  }

  private begin(): void {
    const win = this.window!;
    this.queue.onEnqueue(() => this.schedule(500));
    win.addEventListener('online', () => this.syncNow());
    win.document.addEventListener('visibilitychange', () => {
      if (win.document.visibilityState === 'visible') this.schedule(0);
    });
    setInterval(() => {
      if (win.document.visibilityState === 'visible') void this.sync();
    }, PERIODIC_SYNC_MS);
    if (typeof BroadcastChannel === 'function') {
      this.channel = new BroadcastChannel(CHANNEL_NAME);
      this.channel.onmessage = ({ data }: MessageEvent<ChannelMessage>) => {
        if (data?.type === 'state') {
          this.status.report({ syncing: data.syncing, authRequired: data.authRequired });
        }
      };
    }
    this.watchQueue();
    void win.navigator.storage?.persist?.().catch(() => undefined);
    this.schedule(0);
  }

  /** Feeds outbox counts and the last sync time into the shell's sync indicator (all tabs). */
  private watchQueue(): void {
    liveQuery(async () => {
      const ops = await this.db.outbox.toArray();
      const lastSyncedAt = await getMeta<string>(this.db, 'lastSyncedAt');
      return {
        pendingCount: ops.filter((op) => op.status === 'pending' || op.status === 'inflight')
          .length,
        failedCount: ops.filter((op) => op.status === 'failed' || op.status === 'conflict').length,
        lastSyncedAt: lastSyncedAt ? new Date(lastSyncedAt) : null,
      };
    }).subscribe({
      next: (progress) => this.status.report(progress),
      error: (error: unknown) => console.error('Sync status query failed', error),
    });
  }

  private async withLock<T>(task: () => Promise<T>): Promise<T | null> {
    const locks = this.window?.navigator.locks;
    if (!locks?.request) return task();
    return locks.request(LOCK_NAME, { ifAvailable: true }, (lock) => (lock ? task() : null));
  }

  private async cycle(): Promise<boolean> {
    this.setSyncing(true);
    try {
      await this.withAuth(async () => {
        await this.recoverInflight();
        await this.push();
        await this.pull();
      });
      await setMeta(this.db, 'lastSyncedAt', new Date().toISOString());
      this.connectivity.reportServerReachable(true);
      this.lastErrorState.set(null);
      this.backoffAttempt = 0;
      return true;
    } catch (error) {
      this.handleFailure(SyncHttpError.from(error));
      return false;
    } finally {
      this.setSyncing(false);
    }
  }

  /** On 401, rotates the session via the refresh cookie once, then pauses until the user signs in. */
  private async withAuth(task: () => Promise<void>): Promise<void> {
    try {
      await task();
    } catch (error) {
      if (SyncHttpError.from(error).kind !== 'auth') throw error;
      try {
        await this.api.refresh();
      } catch {
        throw error;
      }
      await task();
    }
  }

  private handleFailure(error: SyncHttpError): void {
    if (error.kind === 'auth') {
      this.connectivity.reportServerReachable(true);
      this.authPaused = true;
      this.status.report({ authRequired: true });
      this.broadcast();
      return;
    }
    if (error.retryable) {
      this.connectivity.reportServerReachable(!error.unreachable);
      this.scheduleRetry();
      return;
    }
    this.connectivity.reportServerReachable(true);
    this.lastErrorState.set(error.message);
  }

  /** Exponential backoff with jitter: ~1 s, 2 s, 4 s … capped at 5 minutes. */
  private scheduleRetry(): void {
    const base = Math.min(MAX_BACKOFF_MS, 1000 * 2 ** this.backoffAttempt);
    this.backoffAttempt++;
    const delay = base / 2 + Math.random() * (base / 2);
    clearTimeout(this.retryTimer);
    this.zone.runOutsideAngular(() => {
      this.retryTimer = setTimeout(() => void this.sync(), delay);
    });
  }

  private setSyncing(syncing: boolean): void {
    this.syncingState.set(syncing);
    if (!syncing && !this.authPaused) {
      this.status.report({ syncing, authRequired: false });
    } else {
      this.status.report({ syncing });
    }
    this.broadcast();
  }

  private broadcast(): void {
    const message: ChannelMessage = {
      type: 'state',
      syncing: this.syncingState(),
      authRequired: this.authPaused,
    };
    this.channel?.postMessage(message);
  }

  /** Operations left "inflight" by a closed tab are re-sent; the server de-duplicates by opId. */
  private async recoverInflight(): Promise<void> {
    await this.db.outbox.where('status').equals('inflight').modify({ status: 'pending' });
  }

  // ---------------------------------------------------------------------------------------------
  // Push
  // ---------------------------------------------------------------------------------------------

  private async push(): Promise<void> {
    let batchSize = PUSH_BATCH_SIZE;
    for (let round = 0; round < 100; round++) {
      const batch = await this.nextBatch(batchSize);
      if (batch.length === 0) return;
      await this.db.transaction('rw', this.db.outbox, async () => {
        for (const op of batch) {
          await this.db.outbox.update(op.seq!, { status: 'inflight', attempts: op.attempts + 1 });
        }
      });
      let results: readonly SyncOperationResult[];
      try {
        results = (await this.api.push(batch.map(toDto))).results;
      } catch (error) {
        const failure = SyncHttpError.from(error);
        if (failure.kind === 'invalid' && batch.length > 1) {
          // One malformed operation fails the whole request: retry one by one to isolate it.
          await this.markBatch(batch, 'pending');
          batchSize = 1;
          continue;
        }
        if (failure.kind === 'invalid') {
          await this.markBatch(batch, 'failed', failure.message);
          continue;
        }
        await this.markBatch(batch, 'pending');
        throw failure;
      }
      await this.applyResults(batch, results);
    }
  }

  /**
   * Oldest pending operations first. Later changes to a record wait behind a failed or conflicting
   * one (and children wait behind their coop), so the server always sees them in order.
   */
  private async nextBatch(size: number): Promise<OutboxOperation[]> {
    const ops = await this.db.outbox.orderBy('seq').toArray();
    const blocked = new Set<string>();
    const batch: OutboxOperation[] = [];
    for (const op of ops) {
      const key = opKey(op);
      const coopKey = op.coopId ? recordKey('COOP', op.coopId) : null;
      if (op.status === 'failed' || op.status === 'conflict') {
        blocked.add(key);
        continue;
      }
      if (blocked.has(key) || (coopKey && blocked.has(coopKey))) continue;
      batch.push(op);
      if (batch.length >= size) break;
    }
    return batch;
  }

  private async markBatch(
    batch: readonly OutboxOperation[],
    status: 'pending' | 'failed',
    message?: string,
  ): Promise<void> {
    await this.db.transaction('rw', this.db.tables, async () => {
      for (const op of batch) {
        await this.db.outbox.update(op.seq!, { status, lastError: message ?? null });
        if (status === 'failed')
          await this.queue.setRecordStatus(op.entityType, op.entityId, 'failed');
      }
    });
  }

  private async applyResults(
    batch: readonly OutboxOperation[],
    results: readonly SyncOperationResult[],
  ): Promise<void> {
    const byOpId = new Map(results.map((result) => [result.opId, result]));
    await this.db.transaction('rw', this.db.tables, async () => {
      for (const sent of batch) {
        // Re-read: the user may have discarded or changed the operation while it was in flight.
        const op = await this.db.outbox.get(sent.seq!);
        if (!op || op.opId !== sent.opId) continue;
        const result = byOpId.get(op.opId);
        if (!result) {
          await this.db.outbox.update(op.seq!, { status: 'pending' });
        } else if (result.status === 'APPLIED') {
          await this.applied(op, result);
        } else if (result.status === 'CONFLICT') {
          await this.conflicted(op, result);
        } else {
          await this.db.outbox.update(op.seq!, {
            status: 'failed',
            lastError: result.message ?? 'Rejected by the server',
            errorCode: result.errorCode ?? null,
            errors: result.errors ?? null,
          });
          await this.queue.setRecordStatus(op.entityType, op.entityId, 'failed');
        }
      }
    });
  }

  private async applied(op: OutboxOperation, result: SyncOperationResult): Promise<void> {
    await this.db.outbox.delete(op.seq!);
    await this.db.conflicts.delete(op.opId);
    const remaining = await this.queue.opsFor(op.entityType, op.entityId);

    // Later changes were made on top of this one, so they are based on the new server version.
    const versioned =
      op.entityType === 'REMINDER' && op.coopId
        ? await this.queue.opsFor('COOP', op.coopId)
        : remaining;
    if (typeof result.version === 'number' && op.operation !== 'DELETE') {
      for (const later of versioned) {
        if (later.status === 'pending') {
          await this.db.outbox.update(later.seq!, { baseVersion: result.version });
        }
      }
    }
    if (op.operation === 'DELETE') return;

    if (op.entityType === 'REMINDER') {
      if (result.serverRecord) {
        await applyServerRecord(this.db, 'COOP', result.serverRecord, await pendingKeys(this.db));
      }
      return;
    }
    const def = entityDef(op.entityType);
    if (!def) return;
    // Removed locally meanwhile (e.g. archived by a new batch): do not bring it back.
    if (!(await def.table(this.db).get(op.entityId))) return;
    if (remaining.length === 0 && result.serverRecord) {
      await applyServerRecord(
        this.db,
        op.entityType,
        result.serverRecord,
        await pendingKeys(this.db),
      );
    } else if (typeof result.version === 'number') {
      await def.table(this.db).update(op.entityId, {
        version: result.version,
        ...(remaining.length === 0 ? { syncStatus: 'synced' as const } : {}),
      });
    }
  }

  private async conflicted(op: OutboxOperation, result: SyncOperationResult): Promise<void> {
    const def = entityDef(op.entityType);
    const merge = def ? mergeConflict(def, op, result.serverRecord) : null;

    if (def && merge?.kind === 'merged' && op.attempts <= MAX_AUTO_MERGES) {
      const later = await this.queue.opsFor(op.entityType, op.entityId);
      const userFields = new Set(later.flatMap((other) => other.fields));
      const current = (await def.table(this.db).get(op.entityId)) as unknown as
        Record<string, unknown> | undefined;
      const mine = Object.fromEntries(
        [...userFields].map((field) => [field, current?.[field] ?? null]),
      );
      await this.db.outbox.update(op.seq!, {
        // The server replays results per opId, so the merged change needs a new one.
        opId: newId(),
        status: 'pending',
        baseVersion: merge.server.version,
        payload: merge.payload,
        baseRecord: merge.server as unknown as Record<string, unknown>,
      });
      await def.table(this.db).put({ ...merge.server, ...mine, syncStatus: 'pending' });
      return;
    }

    const fields = merge?.kind === 'conflict' ? merge.fields : [];
    await this.db.outbox.update(op.seq!, {
      status: 'conflict',
      lastError: result.message ?? 'Changed on the server',
    });
    await this.db.conflicts.put({
      opId: op.opId,
      entityType: op.entityType,
      entityId: op.entityId,
      coopId: op.coopId,
      label: op.label,
      message: result.message ?? 'Changed on the server',
      fields,
      local: op.operation === 'DELETE' ? null : op.payload,
      server: result.serverRecord ?? null,
      createdAt: new Date().toISOString(),
    });
    await this.queue.setRecordStatus(op.entityType, op.entityId, 'conflict');
  }

  // ---------------------------------------------------------------------------------------------
  // Pull
  // ---------------------------------------------------------------------------------------------

  private async pull(): Promise<void> {
    let cursor = await getMeta<number>(this.db, 'cursor');
    if (cursor === null) {
      await this.bootstrap();
      return;
    }
    for (let page = 0; page < 1000; page++) {
      const changes = await this.api.changes(cursor);
      if (changes.resetRequired) {
        await this.bootstrap();
        return;
      }
      await this.db.transaction('rw', this.db.tables, () => applyChanges(this.db, changes));
      if (!changes.hasMore || changes.cursor === cursor) return;
      cursor = changes.cursor;
    }
  }

  private async bootstrap(): Promise<void> {
    const data = await this.api.bootstrap();
    await this.db.transaction('rw', this.db.tables, () => applyBootstrap(this.db, data));
  }
}

function toDto(op: OutboxOperation): SyncOperationDto {
  return {
    opId: op.opId,
    entityType: op.entityType,
    operation: op.operation,
    entityId: op.entityId,
    coopId: op.coopId,
    baseVersion: op.baseVersion,
    payload: op.payload,
  };
}
