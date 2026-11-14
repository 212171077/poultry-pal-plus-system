import { formatRate } from './hatch-results-page';

describe('hatch results helpers', () => {
  it('formats a rate to one decimal', () => {
    expect(formatRate(82.5)).toBe('82.5%');
  });

  it('shows n/a when there is no rate', () => {
    expect(formatRate(null)).toBe('n/a');
  });
});
