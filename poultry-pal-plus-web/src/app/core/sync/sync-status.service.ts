import { Injectable, computed, inject, signal } from '@angular/core';
import { ConnectivityService } from '../network/connectivity.service';

export type SyncState =
  'offline' | 'syncing' | 'attention' | 'auth-required' | 'pending' | 'synced';

export interface SyncProgress {
  readonly pendingCount: number;
  readonly failedCount: number;
  readonly syncing: boolean;
  readonly authRequired: boolean;
  readonly lastSyncedAt: Date | null;
}

const INITIAL: SyncProgress = {
  pendingCount: 0,
  failedCount: 0,
  syncing: false,
  authRequired: false,
  lastSyncedAt: null,
};

/**
 * Read model for the sync indicator in the shell. The Phase 2 sync engine reports progress here;
 * UI components only read the signals.
 */
@Injectable({ providedIn: 'root' })
export class SyncStatusService {
  private readonly connectivity = inject(ConnectivityService);
  private readonly progress = signal<SyncProgress>(INITIAL);

  readonly pendingCount = computed(() => this.progress().pendingCount);
  readonly failedCount = computed(() => this.progress().failedCount);
  readonly lastSyncedAt = computed(() => this.progress().lastSyncedAt);
  readonly syncing = computed(() => this.progress().syncing);
  /** The server session expired; syncing waits until the user signs in again. */
  readonly authRequired = computed(() => this.progress().authRequired);

  /** Most important state first: problems the user must act on outrank routine progress. */
  readonly state = computed<SyncState>(() => {
    const { pendingCount, failedCount, syncing, authRequired, lastSyncedAt } = this.progress();
    if (failedCount > 0) return 'attention';
    if (authRequired) return 'auth-required';
    if (!this.connectivity.online()) return 'offline';
    // A device that has never synced is still downloading the farm, not "synced".
    if (syncing || lastSyncedAt === null) return 'syncing';
    if (pendingCount > 0) return 'pending';
    return 'synced';
  });

  report(update: Partial<SyncProgress>): void {
    this.progress.update((current) => ({ ...current, ...update }));
  }
}
