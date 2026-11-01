import { ChangeDetectionStrategy, Component, Injector, computed, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { SyncStatusService } from '../../core/sync/sync-status.service';
import { openReauthDialog } from '../../features/auth/reauth-dialog/open-reauth-dialog';

/**
 * Session messages under the top bar: an expired session (sign in again to keep syncing) and the
 * first download of the farm's data after signing in on a new device.
 */
@Component({
  selector: 'app-session-notice',
  imports: [MatButtonModule, MatIconModule],
  template: `
    <div role="status" aria-live="polite">
      @switch (notice()) {
        @case ('auth-required') {
          <div class="notice auth">
            <mat-icon aria-hidden="true">lock_clock</mat-icon>
            <p>
              <strong>Your session has expired.</strong>
              Your work is safe on this device. Sign in again to keep syncing.
            </p>
            <button mat-flat-button type="button" (click)="signIn()">Sign in</button>
          </div>
        }
        @case ('first-sync') {
          <div class="notice first-sync">
            <mat-icon aria-hidden="true">cloud_download</mat-icon>
            <p><strong>Downloading your farm data…</strong> This only takes long the first time.</p>
          </div>
          <!-- CSS-only bar: keeps Material's progress bar out of the initial bundle. -->
          <div class="progress" aria-hidden="true"><span></span></div>
        }
      }
    </div>
  `,
  styles: `
    .notice {
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: var(--pp-space-sm) var(--pp-space-md);
      padding: var(--pp-space-sm) var(--pp-space-md);
      font-size: 0.875rem;
      color: var(--mat-sys-on-surface);
    }
    p {
      flex: 1 1 240px;
      margin: 0;
    }
    mat-icon {
      flex: none;
    }
    .auth {
      background: var(--pp-error-container);
      mat-icon {
        color: var(--pp-error);
      }
    }
    .progress {
      position: relative;
      height: 4px;
      overflow: hidden;
      background: color-mix(in srgb, var(--pp-info) 20%, transparent);
      span {
        position: absolute;
        inset: 0 auto 0 0;
        width: 40%;
        background: var(--pp-info);
        animation: slide 1.4s ease-in-out infinite;
      }
    }
    @keyframes slide {
      from {
        transform: translateX(-100%);
      }
      to {
        transform: translateX(250%);
      }
    }
    @media (prefers-reduced-motion: reduce) {
      .progress span {
        animation: none;
        width: 100%;
        opacity: 0.5;
      }
    }
    .first-sync {
      background: var(--pp-info-container);
      mat-icon {
        color: var(--pp-info);
      }
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SessionNotice {
  private readonly status = inject(SyncStatusService);
  private readonly injector = inject(Injector);

  protected readonly notice = computed(() => {
    if (this.status.authRequired()) return 'auth-required';
    if (this.status.syncing() && this.status.lastSyncedAt() === null) return 'first-sync';
    return null;
  });

  protected signIn(): void {
    void openReauthDialog(this.injector);
  }
}
