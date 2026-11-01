import { DOCUMENT, Injectable, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { MatSnackBar } from '@angular/material/snack-bar';
import { SwUpdate, VersionReadyEvent } from '@angular/service-worker';
import { filter, fromEvent, merge, throttleTime } from 'rxjs';

const MIN_CHECK_GAP_MS = 15 * 60 * 1000;

/** Tells the user when a new app version has been downloaded, and lets them reload into it. */
@Injectable({ providedIn: 'root' })
export class AppUpdateService {
  private readonly swUpdate = inject(SwUpdate);
  private readonly snackBar = inject(MatSnackBar);
  private readonly document = inject(DOCUMENT);
  private readonly updateState = signal<
    'checking' | 'current' | 'available' | 'unsupported' | 'error'
  >(this.swUpdate.isEnabled ? 'current' : 'unsupported');
  readonly state = this.updateState.asReadonly();

  constructor() {
    if (!this.swUpdate.isEnabled) {
      return;
    }

    this.swUpdate.versionUpdates
      .pipe(
        filter((event): event is VersionReadyEvent => event.type === 'VERSION_READY'),
        takeUntilDestroyed(),
      )
      .subscribe(() => {
        this.updateState.set('available');
        this.snackBar
          .open('A new version of Poultry Pal Plus is ready.', 'Reload', { duration: 0 })
          .onAction()
          .subscribe(() => this.document.location.reload());
      });

    this.swUpdate.versionUpdates.pipe(takeUntilDestroyed()).subscribe((event) => {
      if (event.type === 'NO_NEW_VERSION_DETECTED') this.updateState.set('current');
      if (event.type === 'VERSION_DETECTED') this.updateState.set('checking');
    });

    this.swUpdate.unrecoverable.pipe(takeUntilDestroyed()).subscribe(() => {
      this.snackBar
        .open('The app needs to reload to keep working offline.', 'Reload', { duration: 0 })
        .onAction()
        .subscribe(() => this.document.location.reload());
    });

    // Check when the farmer returns to the app or reconnects. No timers, so the app can become
    // stable and register the service worker promptly.
    const win = this.document.defaultView;
    if (win) {
      merge(
        fromEvent(this.document, 'visibilitychange').pipe(
          filter(() => this.document.visibilityState === 'visible'),
        ),
        fromEvent(win, 'online'),
      )
        .pipe(throttleTime(MIN_CHECK_GAP_MS), takeUntilDestroyed())
        .subscribe(() => {
          if (win.navigator.onLine) {
            this.swUpdate.checkForUpdate().catch(() => undefined);
          }
        });
    }
  }

  async checkForUpdate(): Promise<void> {
    if (!this.swUpdate.isEnabled) {
      this.updateState.set('unsupported');
      return;
    }
    this.updateState.set('checking');
    try {
      const available = await this.swUpdate.checkForUpdate();
      this.updateState.set(available ? 'available' : 'current');
    } catch {
      this.updateState.set('error');
    }
  }
}
