import { startOfDay } from 'date-fns';
import { LocalReminder, ReminderType } from '../../data/models/local';

export type ReminderBucket = 'overdue' | 'today' | 'upcoming' | 'done';

export const REMINDER_ACTIONS = {
  completed: 'Completed',
  notApplicable: 'Not Applicable',
  removed: 'Remove Task',
} as const;

export function bucketOf(reminder: LocalReminder, now: Date): ReminderBucket {
  if (reminder.done) return 'done';
  if (!reminder.dueDate) return 'upcoming';
  const today = startOfDay(now).getTime();
  const due = startOfDay(new Date(reminder.dueDate)).getTime();
  if (due < today) return 'overdue';
  return due === today ? 'today' : 'upcoming';
}

export type ReminderGroups = Record<ReminderBucket, LocalReminder[]>;

/** Splits reminders into overdue / today / upcoming (soonest first) and done (latest first). */
export function groupReminders(reminders: readonly LocalReminder[], now: Date): ReminderGroups {
  const groups: ReminderGroups = { overdue: [], today: [], upcoming: [], done: [] };
  for (const reminder of reminders) groups[bucketOf(reminder, now)].push(reminder);
  const time = (value: string | null | undefined) =>
    value ? new Date(value).getTime() : Number.POSITIVE_INFINITY;
  for (const key of ['overdue', 'today', 'upcoming'] as const) {
    groups[key].sort((a, b) => time(a.dueDate) - time(b.dueDate));
  }
  groups.done.sort((a, b) => time(b.doneDate) - time(a.doneDate));
  return groups;
}

export const REMINDER_ICONS: Readonly<Record<ReminderType, string>> = {
  FEED: 'grass',
  VACCINE: 'vaccines',
  MEDICINE: 'medication',
};

export const REMINDER_LABELS: Readonly<Record<ReminderType, string>> = {
  FEED: 'Feed',
  VACCINE: 'Vaccine',
  MEDICINE: 'Medicine',
};
