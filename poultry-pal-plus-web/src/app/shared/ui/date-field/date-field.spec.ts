import { parseIsoDate, toIsoDate } from './date-field';

describe('date-field helpers', () => {
  it('round-trips an ISO date without timezone drift', () => {
    expect(toIsoDate(parseIsoDate('2026-03-01')!)).toBe('2026-03-01');
  });

  it('returns null for empty or invalid input', () => {
    expect(parseIsoDate('')).toBeNull();
    expect(parseIsoDate('03/01/2026')).toBeNull();
  });
});
