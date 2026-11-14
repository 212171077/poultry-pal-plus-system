import { batchReference } from './batch-reference';

describe('batchReference', () => {
  it('builds {MON}{DD}-{eggs}', () => {
    expect(batchReference('2026-11-03', 1000)).toBe('NOV03-1000');
  });

  it('is empty until the date and eggs are known', () => {
    expect(batchReference('', 100)).toBe('');
    expect(batchReference('2026-11-03', null)).toBe('');
    expect(batchReference('2026-11-03', 0)).toBe('');
  });
});
