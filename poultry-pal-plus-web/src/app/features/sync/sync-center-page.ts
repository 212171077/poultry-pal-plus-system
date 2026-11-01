import {
  ChangeDetectionStrategy,
  Component,
  Injector,
  computed,
  inject,
  signal,
} from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSnackBar } from '@angular/material/snack-bar';
import { formatDistanceToNow } from 'date-fns';
import { filter } from 'rxjs';
import { ConnectivityService } from '../../core/network/connectivity.service';
import { SyncState, SyncStatusService } from '../../core/sync/sync-status.service';
import { APP_DB } from '../../data/db/app-db';
import { liveSignal } from '../../data/db/live-signal';
import { OutboxOperation, SyncConflict } from '../../data/models/local';
import { SyncEngine } from '../../data/sync/sync-engine';
import { SyncQueue } from '../../data/sync/sync-queue';
import { ConfirmDialogService } from '../../shared/ui/confirm-dialog/confirm-dialog.service';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import { openReauthDialog } from '../auth/reauth-dialog/open-reauth-dialog';
import {
  ConflictChoice,
  ConflictDialog,
  ConflictDialogData,
} from './conflict-dialog/conflict-dialog';

interface StateCopy {
  readonly icon: string;
  readonly title: string;
  readonly message: string;
}

const STATE_COPY: Readonly<Record<SyncState, StateCopy>> = {
  synced: {
    icon: 'cloud_done',
    title: 'Everything is synced',
    message: 'All changes on this device are saved on the server.',
  },
  pending: {
    icon: 'cloud_upload',
    title: 'Changes waiting to sync',
    message: 'They are safe on this device and will be sent automatically.',
  },
  syncing: {
    icon: 'sync',
    title: 'Syncing…',
    message: 'Sending your changes and fetching updates from your team.',
  },
  offline: {
    icon: 'cloud_off',
    title: "You're offline",
    message: 'Keep working. Changes are saved on this device and sync when you reconnect.',
  },
  'auth-required': {
    icon: 'lock_clock',
    title: 'Sign in to sync',
    message:
      'Your session has expired. Your changes are kept on this device until you sign in again.',
  },
  attention: {
    icon: 'report',
    title: 'Some changes need your attention',
    message: 'Review the items below so they can be saved on the server.',
  },
};

const OPERATION_VERBS: Readonly<Record<OutboxOperation['operation'], string>> = {
  UPSERT: 'Save',
  DELETE: 'Delete',
  ACTION: 'Update',
};

@Component({
  selector: 'app-sync-center-page',
  imports: [PageHeader, EmptyState, MatButtonModule, MatIconModule, MatProgressBarModule],
  templateUrl: './sync-center-page.html',
  styleUrl: './sync-center-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class SyncCenterPage {
  private readonly db = inject(APP_DB);
  private readonly engine = inject(SyncEngine);
  private readonly queue = inject(SyncQueue);
  private readonly status = inject(SyncStatusService);
  private readonly dialog = inject(MatDialog);
  private readonly injector = inject(Injector);
  private readonly confirmDialog = inject(ConfirmDialogService);
  private readonly snackBar = inject(MatSnackBar);

  protected readonly online = inject(ConnectivityService).online;
  protected readonly syncing = this.engine.syncing;
  protected readonly lastError = this.engine.lastError;
  protected readonly state = this.status.state;
  protected readonly authRequired = this.status.authRequired;
  protected readonly copy = computed(() => STATE_COPY[this.state()]);
  protected readonly lastSynced = computed(() => {
    const at = this.status.lastSyncedAt();
    return at ? formatDistanceToNow(at, { addSuffix: true }) : null;
  });

  private readonly ops = liveSignal(() => this.db.outbox.orderBy('seq').toArray());
  private readonly conflicts = liveSignal(() => this.db.conflicts.toArray(), []);

  protected readonly loading = computed(() => this.ops() === undefined);
  protected readonly waiting = computed(() =>
    (this.ops() ?? []).filter((op) => op.status === 'pending' || op.status === 'inflight'),
  );
  protected readonly failed = computed(() =>
    (this.ops() ?? []).filter((op) => op.status === 'failed'),
  );
  protected readonly conflictItems = computed(() => {
    const byOpId = new Map(this.conflicts().map((conflict) => [conflict.opId, conflict]));
    return (this.ops() ?? [])
      .filter((op) => op.status === 'conflict')
      .map((op) => ({ op, conflict: byOpId.get(op.opId) ?? null }));
  });
  protected readonly attentionCount = computed(
    () => this.failed().length + this.conflictItems().length,
  );

  protected readonly storage = signal<{ used: string; quota: string } | null>(null);

  constructor() {
    void this.loadStorageEstimate();
  }

  protected verb(op: OutboxOperation): string {
    return OPERATION_VERBS[op.operation];
  }

  protected age(op: OutboxOperation): string {
    return formatDistanceToNow(new Date(op.createdAt), { addSuffix: true });
  }

  protected async syncNow(): Promise<void> {
    const ok = await this.engine.syncNow();
    if (ok) {
      this.snackBar.open('Sync complete', undefined, { duration: 3000 });
    }
  }

  protected signIn(): void {
    void openReauthDialog(this.injector);
  }

  protected async retry(op: OutboxOperation): Promise<void> {
    await this.queue.retry(op.opId);
  }

  protected discard(op: OutboxOperation): void {
    this.confirmDialog
      .confirm({
        title: 'Discard this change?',
        message: `"${op.label}" will be removed from this device and never sent. Later changes to the same record are discarded too.`,
        confirmText: 'Discard',
        destructive: true,
      })
      .pipe(filter(Boolean))
      .subscribe(() => void this.queue.discard(op.opId));
  }

  protected review(op: OutboxOperation, conflict: SyncConflict | null): void {
    if (!conflict) {
      this.discard(op);
      return;
    }
    this.dialog
      .open<ConflictDialog, ConflictDialogData, ConflictChoice>(ConflictDialog, {
        data: { conflict },
        width: '640px',
        maxWidth: 'calc(100vw - 32px)',
      })
      .afterClosed()
      .subscribe((choice) => {
        if (choice === 'mine') void this.queue.keepMine(op.opId);
        if (choice === 'server') void this.queue.useServer(op.opId);
      });
  }

  protected redownload(): void {
    this.confirmDialog
      .confirm({
        title: 'Download a fresh copy?',
        message:
          'Farm data on this device is replaced with the latest copy from the server. Changes that are still waiting to sync are kept.',
        confirmText: 'Download',
      })
      .pipe(filter(Boolean))
      .subscribe(() => void this.engine.redownload());
  }

  private async loadStorageEstimate(): Promise<void> {
    const estimate = await navigator.storage?.estimate?.().catch(() => null);
    if (!estimate?.usage || !estimate.quota) return;
    this.storage.set({ used: formatBytes(estimate.usage), quota: formatBytes(estimate.quota) });
  }
}

function formatBytes(bytes: number): string {
  const units = ['B', 'KB', 'MB', 'GB'];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return `${value.toFixed(unit === 0 ? 0 : 1)} ${units[unit]}`;
}
