import { fromPercent, toPercent } from './production-settings-page';

describe('production settings helpers', () => {
  it('converts rates to percentages and back', () => {
    expect(toPercent(0.8)).toBe(80);
    expect(toPercent(0.0525)).toBe(5.25);
    expect(fromPercent(5.25)).toBe(0.0525);
    expect(fromPercent(80)).toBe(0.8);
  });
});
