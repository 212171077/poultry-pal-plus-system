import { addDaysIso, todayIso } from './schedule-page';

describe('schedule page helpers', () => {
  it('adds days across a month boundary', () => {
    expect(addDaysIso('2026-01-30', 3)).toBe('2026-02-02');
  });

  it('formats today as an ISO date', () => {
    expect(todayIso()).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });
});
