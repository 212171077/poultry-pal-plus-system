import { DOCUMENT, DestroyRef, Injectable, computed, inject, signal } from '@angular/core';

/**
 * Connectivity as signals. `navigator.onLine` only says a network interface exists (captive portals,
 * dead Wi-Fi and a stopped backend all report "online"), so the sync engine also reports whether the
 * server actually answered. Its periodic pull doubles as the heartbeat.
 */
@Injectable({ providedIn: 'root' })
export class ConnectivityService {
  private readonly window = inject(DOCUMENT).defaultView;
  private readonly browserOnlineState = signal(this.window?.navigator.onLine ?? true);
  private readonly serverReachableState = signal(true);

  /** The browser reports a network connection. */
  readonly browserOnline = this.browserOnlineState.asReadonly();
  /** The last request to the backend got an answer (any HTTP status from the app itself). */
  readonly serverReachable = this.serverReachableState.asReadonly();
  /** Data can be synced right now. */
  readonly online = computed(() => this.browserOnlineState() && this.serverReachableState());

  constructor() {
    const win = this.window;
    if (!win) {
      return;
    }
    const setOnline = () => {
      this.browserOnlineState.set(true);
      // Assume the server is back until the next request proves otherwise.
      this.serverReachableState.set(true);
    };
    const setOffline = () => this.browserOnlineState.set(false);
    win.addEventListener('online', setOnline);
    win.addEventListener('offline', setOffline);
    inject(DestroyRef).onDestroy(() => {
      win.removeEventListener('online', setOnline);
      win.removeEventListener('offline', setOffline);
    });
  }

  reportServerReachable(reachable: boolean): void {
    this.serverReachableState.set(reachable);
  }
}
