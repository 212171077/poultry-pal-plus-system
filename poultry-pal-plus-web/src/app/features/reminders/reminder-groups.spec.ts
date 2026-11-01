import { LocalReminder } from '../../data/models/local';
import { bucketOf, groupReminders } from './reminder-groups';

const NOW = new Date(2026, 5, 15, 14);
const reminder = (id: string, dueDate: Date | null, done = false): LocalReminder => ({
  id,
  coopId: 'c',
  reminderType: 'VACCINE',
  name: id,
  dueDate: dueDate?.toISOString() ?? null,
  done,
  doneDate: done ? NOW.toISOString() : null,
  syncStatus: 'synced',
});

describe('reminder groups', () => {
  it('classifies by due date and completion', () => {
    expect(bucketOf(reminder('a', new Date(2026, 5, 14, 23)), NOW)).toBe('overdue');
    expect(bucketOf(reminder('b', new Date(2026, 5, 15, 1)), NOW)).toBe('today');
    expect(bucketOf(reminder('c', new Date(2026, 5, 16)), NOW)).toBe('upcoming');
    expect(bucketOf(reminder('d', new Date(2026, 5, 1), true), NOW)).toBe('done');
  });

  it('sorts the soonest first', () => {
    const groups = groupReminders(
      [reminder('later', new Date(2026, 5, 20)), reminder('sooner', new Date(2026, 5, 16))],
      NOW,
    );
    expect(groups.upcoming.map((r) => r.id)).toEqual(['sooner', 'later']);
  });
});
