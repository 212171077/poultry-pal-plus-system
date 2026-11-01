import { ChangeDetectionStrategy, Component, computed, inject, input } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule } from '@angular/material/tooltip';
import { RouterLink } from '@angular/router';
import { SyncState, SyncStatusService } from '../../../core/sync/sync-status.service';

interface SyncView {
  readonly icon: string;
  readonly label: string;
  readonly description: string;
}

/** Shows whether local changes have reached the server. Opens the Sync center. */
@Component({
  selector: 'app-sync-badge',
  imports: [RouterLink, MatIconModule, MatTooltipModule],
  template: `
    <a
      class="badge"
      routerLink="/sync"
      [attr.data-state]="state()"
      [matTooltip]="view().description"
      [attr.aria-label]="'Sync status: ' + view().label + '. ' + view().description"
    >
      <mat-icon aria-hidden="true" [class.spin]="state() === 'syncing'">{{ view().icon }}</mat-icon>
      @if (!compact()) {
        <span aria-hidden="true">{{ view().label }}</span>
      }
    </a>
  `,
  styleUrl: './sync-badge.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SyncBadge {
  /** Icon only (small screens). */
  readonly compact = input(false);

  private readonly sync = inject(SyncStatusService);
  protected readonly state = this.sync.state;

  protected readonly view = computed<SyncView>(() => {
    const pending = this.sync.pendingCount();
    const failed = this.sync.failedCount();
    const views: Record<SyncState, SyncView> = {
      synced: {
        icon: 'cloud_done',
        label: 'Synced',
        description: 'All changes are saved to the server.',
      },
      pending: {
        icon: 'cloud_upload',
        label: `${pending} pending`,
        description: `${pending} change(s) are waiting to be sent.`,
      },
      syncing: { icon: 'sync', label: 'Syncing', description: 'Sending your changes…' },
      offline: {
        icon: 'cloud_off',
        label: pending > 0 ? `Offline · ${pending}` : 'Offline',
        description: 'You are offline. Changes are saved on this device and sync later.',
      },
      'auth-required': {
        icon: 'lock',
        label: 'Sign in',
        description: 'Sign in again so your changes can sync.',
      },
      attention: {
        icon: 'sync_problem',
        label: `${failed} need attention`,
        description: `${failed} change(s) could not be synced. Open the Sync center to review.`,
      },
    };
    return views[this.state()];
  });
}
