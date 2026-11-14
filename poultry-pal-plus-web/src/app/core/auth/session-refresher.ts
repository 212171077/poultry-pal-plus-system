import { Injectable, inject } from '@angular/core';
import { SyncApi } from '../../data/sync/sync-api';

/**
 * Rotates the session through the refresh cookie. Refresh tokens are single-use, so concurrent
 * callers (the sync engine and any API request that got a 401) must share one in-flight refresh;
 * a second parallel rotation would present an already-used token and sign the user out.
 */
@Injectable({ providedIn: 'root' })
export class SessionRefresher {
  private readonly api = inject(SyncApi);
  private inFlight: Promise<void> | null = null;

  refresh(): Promise<void> {
    this.inFlight ??= this.api
      .refresh()
      .then(() => undefined)
      .finally(() => {
        this.inFlight = null;
      });
    return this.inFlight;
  }
}
