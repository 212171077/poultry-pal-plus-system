import { DOCUMENT, Injectable, inject, signal } from '@angular/core';
import { format } from 'date-fns';

const LAST_NOTIFIED_KEY = 'pp.reminders.notified';

/** Optional browser notifications for reminders that are due. Never required to use the app. */
@Injectable({ providedIn: 'root' })
export class ReminderNotifications {
  private readonly window = inject(DOCUMENT).defaultView;
  readonly supported = this.window !== null && 'Notification' in this.window;
  private readonly permissionState = signal<NotificationPermission>(
    this.supported ? Notification.permission : 'denied',
  );
  readonly permission = this.permissionState.asReadonly();

  async enable(): Promise<NotificationPermission> {
    if (!this.supported) return 'denied';
    this.permissionState.set(await Notification.requestPermission());
    return this.permissionState();
  }

  /** Shows one notification per day when reminders are due and permission was granted. */
  notifyDue(count: number, now = new Date()): void {
    if (!this.supported || this.permissionState() !== 'granted' || count <= 0) return;
    const today = format(now, 'yyyy-MM-dd');
    try {
      if (this.window?.localStorage.getItem(LAST_NOTIFIED_KEY) === today) return;
      this.window?.localStorage.setItem(LAST_NOTIFIED_KEY, today);
      new Notification('Poultry Pal Plus', {
        body: count === 1 ? '1 farm task needs attention' : `${count} farm tasks need attention`,
        icon: 'icons/icon-192x192.png',
        tag: 'pp-reminders',
      });
    } catch {
      // Notifications can be blocked by the platform; they are only a convenience.
    }
  }
}
