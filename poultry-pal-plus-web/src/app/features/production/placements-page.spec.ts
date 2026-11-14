import { MOVEMENT_LABELS, occupancyPercent, todayIso } from './placements-page';

describe('placements page helpers', () => {
  it('formats today as an ISO date', () => {
    expect(todayIso()).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('computes occupancy percent and caps at 100', () => {
    expect(occupancyPercent({ capacity: 800, occupied: 200 })).toBe(25);
    expect(occupancyPercent({ capacity: 100, occupied: 150 })).toBe(100);
    expect(occupancyPercent({ capacity: 0, occupied: 0 })).toBe(0);
  });

  it('labels every movement type', () => {
    expect(Object.keys(MOVEMENT_LABELS).length).toBe(5);
  });
});
