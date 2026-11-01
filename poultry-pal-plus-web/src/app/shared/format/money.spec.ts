import { formatMoney } from './money';

describe('formatMoney', () => {
  it('uses Intl currency formatting for ISO codes', () => {
    expect(formatMoney(12.5, 'USD')).toContain('12.50');
    expect(formatMoney(12.5, 'USD')).toMatch(/\$|USD/);
  });

  it('prefixes symbols and plain values', () => {
    expect(formatMoney(1234.5, 'R')).toMatch(/^R 1.?234.50$/);
    expect(formatMoney(3, null)).toBe((3).toLocaleString(undefined, { minimumFractionDigits: 2 }));
  });
});
