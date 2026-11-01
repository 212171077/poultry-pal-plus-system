import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';
import { SyncStatus } from '../../../data/models/local';

const LABELS: Readonly<Record<SyncStatus, { label: string; icon: string }>> = {
  synced: { label: 'Synced', icon: 'cloud_done' },
  pending: { label: 'Waiting to sync', icon: 'cloud_upload' },
  failed: { label: 'Sync failed', icon: 'error' },
  conflict: { label: 'Needs review', icon: 'merge_type' },
};

/** Small per-record badge showing whether a change has reached the server. */
@Component({
  selector: 'app-sync-chip',
  imports: [MatIconModule],
  template: `
    <mat-icon aria-hidden="true">{{ meta().icon }}</mat-icon>
    @if (!compact() || status() !== 'synced') {
      <span>{{ meta().label }}</span>
    } @else {
      <span class="pp-sr-only">{{ meta().label }}</span>
    }
  `,
  styles: `
    :host {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 2px 8px;
      border-radius: var(--pp-radius-pill);
      font-size: 0.75rem;
      font-weight: 600;
      white-space: nowrap;
      vertical-align: middle;
    }
    mat-icon {
      width: 16px;
      height: 16px;
      font-size: 16px;
    }
    :host(.synced) {
      padding: 2px;
      color: var(--pp-success);
    }
    :host(.pending) {
      background: var(--pp-info-container);
      color: var(--pp-info);
    }
    :host(.failed) {
      background: var(--pp-error-container);
      color: var(--pp-error);
    }
    :host(.conflict) {
      background: var(--pp-warning-container);
      color: var(--pp-warning);
    }
  `,
  host: { '[class]': 'status()' },
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SyncChip {
  readonly status = input.required<SyncStatus>();
  /** Shows only an icon for synced records. */
  readonly compact = input(true);
  protected readonly meta = computed(() => LABELS[this.status()]);
}
