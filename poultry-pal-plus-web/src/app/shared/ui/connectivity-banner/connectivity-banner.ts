import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';
import { ConnectivityService } from '../../../core/network/connectivity.service';

/** Announces offline mode. The live region always exists so screen readers hear the change. */
@Component({
  selector: 'app-connectivity-banner',
  imports: [MatIconModule],
  template: `
    <div role="status" aria-live="polite">
      @if (!online()) {
        <div class="banner">
          <mat-icon aria-hidden="true">wifi_off</mat-icon>
          <p>
            <strong>You're offline.</strong>
            Keep working — changes are saved on this device and sync when you're back online.
          </p>
        </div>
      }
    </div>
  `,
  styles: `
    .banner {
      display: flex;
      align-items: center;
      gap: var(--pp-space-sm);
      padding: var(--pp-space-sm) var(--pp-space-md);
      background: var(--pp-warning-container);
      color: var(--mat-sys-on-surface);
      font-size: 0.875rem;
    }
    mat-icon {
      flex: none;
      color: var(--pp-warning);
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ConnectivityBanner {
  protected readonly online = inject(ConnectivityService).online;
}
