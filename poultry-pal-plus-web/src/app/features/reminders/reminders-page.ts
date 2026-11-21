import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { MatDialog } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatSelectModule } from '@angular/material/select';
import { Toast } from '../../shared/ui/toast/toast.service';
import { format } from 'date-fns';
import { liveSignal } from '../../data/db/live-signal';
import { APP_DB } from '../../data/db/app-db';
import { LocalReminder } from '../../data/models/local';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import { SyncChip } from '../../shared/ui/sync-chip/sync-chip';
import {
  ReminderActionData,
  ReminderActionDialog,
} from './reminder-action-dialog/reminder-action-dialog';
import { ReminderNotifications } from './reminder-notifications';
import { REMINDER_ICONS, REMINDER_LABELS, ReminderBucket, groupReminders } from './reminder-groups';

type Tab = 'attention' | 'upcoming' | 'done';

interface ReminderRow {
  readonly reminder: LocalReminder;
  readonly coopName: string;
  readonly icon: string;
  readonly kind: string;
  readonly due: string;
  readonly bucket: ReminderBucket;
}

const TAB_LABELS: Readonly<Record<Tab, string>> = {
  attention: 'Tasks needing attention',
  upcoming: 'Upcoming Tasks',
  done: 'Completed Tasks',
};

const EMPTY_MESSAGES: Readonly<Record<Tab, { heading: string; message: string }>> = {
  attention: {
    heading: 'Nothing needs attention',
    message: 'Overdue and due-today tasks appear here.',
  },
  upcoming: {
    heading: 'No upcoming tasks',
    message: 'Vaccination, feeding and medication tasks appear here once scheduled.',
  },
  done: { heading: 'Nothing completed yet', message: 'Tasks you complete show up here.' },
};

@Component({
  selector: 'app-reminders-page',
  imports: [
    PageHeader,
    EmptyState,
    SyncChip,
    MatButtonModule,
    MatButtonToggleModule,
    MatIconModule,
    MatFormFieldModule,
    MatSelectModule,
  ],
  templateUrl: './reminders-page.html',
  styleUrl: './reminders-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class RemindersPage {
  private readonly db = inject(APP_DB);
  private readonly dialog = inject(MatDialog);
  private readonly snackBar = inject(Toast);
  protected readonly notifications = inject(ReminderNotifications);

  private readonly now = new Date();
  private readonly data = liveSignal(async () => {
    const [reminders, coops] = await Promise.all([
      this.db.reminders.toArray(),
      this.db.coops.toArray(),
    ]);
    const sorted = [...coops].sort((a, b) => a.coopName.localeCompare(b.coopName));
    return {
      reminders,
      coops: sorted.map((coop) => ({ id: coop.id, name: coop.coopName })),
      names: new Map(coops.map((coop) => [coop.id, coop.coopName])),
    };
  });

  protected readonly tab = signal<Tab>('attention');
  /** Selected coop id, or '' for all coops. */
  protected readonly coopId = signal('');
  protected readonly coops = computed(() => this.data()?.coops ?? []);
  protected readonly tabLabel = computed(() => {
    const coop = this.coops().find((c) => c.id === this.coopId());
    return coop ? `${TAB_LABELS[this.tab()]} · ${coop.name}` : TAB_LABELS[this.tab()];
  });
  protected readonly loading = computed(() => this.data() === undefined);

  private readonly groups = computed(() => {
    const coopId = this.coopId();
    const all = this.data()?.reminders ?? [];
    return groupReminders(coopId ? all.filter((r) => r.coopId === coopId) : all, this.now);
  });

  protected readonly counts = computed(() => {
    const groups = this.groups();
    return {
      attention: groups.overdue.length + groups.today.length,
      upcoming: groups.upcoming.length,
      done: groups.done.length,
      overdue: groups.overdue.length,
    };
  });

  protected readonly rows = computed<ReminderRow[]>(() => {
    const groups = this.groups();
    const names = this.data()?.names ?? new Map<string, string>();
    const tab = this.tab();
    const entries: [ReminderBucket, LocalReminder][] =
      tab === 'attention'
        ? [
            ...groups.overdue.map((r): [ReminderBucket, LocalReminder] => ['overdue', r]),
            ...groups.today.map((r): [ReminderBucket, LocalReminder] => ['today', r]),
          ]
        : (tab === 'upcoming' ? groups.upcoming : groups.done).map((r) => [
            tab === 'upcoming' ? 'upcoming' : 'done',
            r,
          ]);
    return entries.map(([bucket, reminder]) => ({
      reminder,
      bucket,
      coopName: names.get(reminder.coopId) ?? 'Unknown coop',
      icon: REMINDER_ICONS[reminder.reminderType] ?? 'event',
      kind: REMINDER_LABELS[reminder.reminderType] ?? reminder.reminderType,
      due: reminder.dueDate ? format(new Date(reminder.dueDate), 'd MMM yyyy') : 'No due date',
    }));
  });

  protected readonly empty = computed(() => EMPTY_MESSAGES[this.tab()]);

  protected doneOn(reminder: LocalReminder): string {
    return reminder.doneDate ? format(new Date(reminder.doneDate), 'd MMM yyyy') : '';
  }

  protected async enableNotifications(): Promise<void> {
    const result = await this.notifications.enable();
    this.snackBar.open(
      result === 'granted'
        ? 'Notifications are on'
        : 'Notifications are blocked. You can allow them in your browser settings.',
      'OK',
      { duration: 4000 },
    );
    if (result === 'granted') this.notifications.notifyDue(this.counts().attention);
  }

  protected act(reminder: LocalReminder, kind: ReminderActionData['kind']): void {
    this.dialog
      .open<ReminderActionDialog, ReminderActionData, boolean>(ReminderActionDialog, {
        data: { reminder, kind },
        autoFocus: 'first-tabbable',
        maxWidth: '95vw',
      })
      .afterClosed()
      .subscribe((saved) => {
        if (saved) {
          this.snackBar.open('Task updated. It will sync automatically.', undefined, {
            duration: 3000,
          });
        }
      });
  }
}
