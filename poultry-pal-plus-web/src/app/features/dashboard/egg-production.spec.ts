import { LocalCoop, LocalEggRecord } from '../../data/models/local';
import { FarmData, rangeFor } from '../analytics/farm-metrics';
import { eggProduction, levelFor } from './egg-production';

const base = { version: 1, syncStatus: 'synced' as const };
const NOW = new Date(2026, 5, 15, 10);
const layers: LocalCoop = {
  ...base,
  id: 'a',
  coopName: 'Alpha',
  coopType: 'LAYERS',
  growthPhase: 'PRODUCTION_FINISHING_PHASE',
  numberOfChickens: 100,
};
const eggs = (id: string, day: number, total: number): LocalEggRecord => ({
  ...base,
  id,
  coopId: 'a',
  createdDate: new Date(2026, 5, day, 9).toISOString(),
  boxSize: '30',
  numberOfBoxes: 1,
  totalEggs: total,
});
const data = (records: LocalEggRecord[], coops = [layers]): FarmData => ({
  coops,
  sales: [],
  expenses: [],
  mortalities: [],
  eggRecords: records,
});

describe('egg production', () => {
  it('classifies the hen-day rate', () => {
    expect(levelFor(90)).toBe('peak');
    expect(levelFor(75)).toBe('normal');
    expect(levelFor(40)).toBe('below');
  });

  it('is null without layers coops', () => {
    expect(
      eggProduction(data([], [{ ...layers, coopType: 'BROILER' }]), rangeFor('7d', NOW), NOW),
    ).toBeNull();
  });

  it('builds a daily series and rates it against live hens', () => {
    const result = eggProduction(
      data([eggs('1', 14, 80), eggs('2', 15, 60)]),
      rangeFor('7d', NOW),
      NOW,
    )!;
    expect(result.eggsPerDay.length).toBe(7);
    expect(result.recordedDays).toBe(2);
    expect(result.averageEggs).toBe(70);
    expect(result.rate).toBe(70);
    expect(result.level).toBe('normal');
  });

  it('has no verdict without egg records', () => {
    expect(eggProduction(data([]), rangeFor('7d', NOW), NOW)!.level).toBeNull();
  });
});
