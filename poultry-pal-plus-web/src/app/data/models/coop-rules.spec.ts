import { LocalCoop } from './local';
import {
  duePhaseChange,
  expectedGrowthPhase,
  flockAgeLabel,
  isCoopActive,
  mortalityRate,
  transitionTargets,
} from './coop-rules';

describe('coop rules', () => {
  const now = new Date('2026-03-01T12:00:00.000Z');
  const weeksAgo = (weeks: number, days = 0) =>
    new Date(now.getTime() - (weeks * 7 + days) * 24 * 60 * 60 * 1000).toISOString();
  const coop = (fields: Partial<LocalCoop>): LocalCoop => ({
    id: 'c1',
    coopName: 'A',
    coopType: 'BROILER',
    growthPhase: 'BROODING_PHASE',
    numberOfChickens: 100,
    version: 1,
    syncStatus: 'synced',
    ...fields,
  });

  it('formats the flock age like the server', () => {
    expect(flockAgeLabel(weeksAgo(0, 1), now)).toBe('1 day');
    expect(flockAgeLabel(weeksAgo(3, 2), now)).toBe('3 weeks and 2 days');
    expect(flockAgeLabel(weeksAgo(1), now)).toBe('1 week');
    expect(flockAgeLabel(null, now)).toBe('Unknown');
  });

  it('derives the expected phase per coop type', () => {
    expect(expectedGrowthPhase(weeksAgo(2), 'BROILER', now)).toBe('BROODING_PHASE');
    expect(expectedGrowthPhase(weeksAgo(4), 'BROILER', now)).toBe('GROWING_REARING_PHASE');
    expect(expectedGrowthPhase(weeksAgo(9), 'BROILER', now)).toBe('PRODUCTION_FINISHING_PHASE');
    expect(expectedGrowthPhase(weeksAgo(9), 'LAYERS', now)).toBe('GROWING_REARING_PHASE');
    expect(expectedGrowthPhase(weeksAgo(18), 'LAYERS', now)).toBe('PRODUCTION_FINISHING_PHASE');
  });

  it('flags coops due for a phase change', () => {
    expect(duePhaseChange(coop({ chickenArrivalDate: weeksAgo(4) }), now)).toBe(
      'GROWING_REARING_PHASE',
    );
    expect(duePhaseChange(coop({ chickenArrivalDate: weeksAgo(1) }), now)).toBeNull();
    expect(
      duePhaseChange(coop({ chickenArrivalDate: weeksAgo(4), numberOfChickens: 0 }), now),
    ).toBeNull();
  });

  it('is active only once the flock has arrived', () => {
    expect(isCoopActive(coop({ chickenArrivalDate: weeksAgo(1) }), now)).toBeTrue();
    expect(isCoopActive(coop({ chickenArrivalDate: null }), now)).toBeFalse();
    expect(
      isCoopActive(coop({ chickenArrivalDate: weeksAgo(1), numberOfChickens: 0 }), now),
    ).toBeFalse();
  });

  it('offers only empty coops of the same type as targets', () => {
    const source = coop({});
    const targets = transitionTargets(source, [
      source,
      coop({ id: 'empty', numberOfChickens: 0 }),
      coop({ id: 'full' }),
      coop({ id: 'layers', coopType: 'LAYERS', numberOfChickens: 0 }),
    ]);
    expect(targets.map((c) => c.id)).toEqual(['empty']);
  });

  it('computes the mortality rate', () => {
    expect(mortalityRate(95, 5)).toBe(5);
    expect(mortalityRate(0, 0)).toBe(0);
  });
});
