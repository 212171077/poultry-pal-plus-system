import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { DatePipe } from '@angular/common';

/** Tells the user that the lists below are the copy saved on this device, not live data. */
@Component({
  selector: 'app-offline-data-note',
  imports: [DatePipe],
  template: `
    @if (since(); as date) {
      <p class="note" role="status">
        Showing data saved on this device ({{ date | date: 'medium' }}). Changes you make will sync
        when you are online.
      </p>
    }
  `,
  styles: `
    .note {
      margin: 0 0 var(--pp-space-3, 12px);
      padding: 8px 12px;
      border-radius: 8px;
      background: var(--mat-sys-secondary-container);
      color: var(--mat-sys-on-secondary-container);
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class OfflineDataNote {
  readonly since = input<Date | null>(null);
}
