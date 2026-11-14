import { PlanCalculation } from './production-api';
import { PLAN_STATUS_LABELS, describeCalculation } from './plans-page';

const base: PlanCalculation = {
  sourceMethod: 'INCUBATE_EGGS',
  targetReadyDate: '2027-03-01',
  targetQuantity: 1000,
  targetAgeDays: 42,
  housePlacementDate: '2027-01-18',
  hatchOrArrivalDate: '2027-01-18',
  incubationStartDate: '2026-12-28',
  transferDate: '2027-01-15',
  latestOrderDate: null,
  eggsRequired: 1316,
  chicksRequired: 1053,
  feasible: true,
  constraints: [],
  assumptions: [],
  calculatedAt: '2026-11-02T00:00:00Z',
};

describe('plans page helpers', () => {
  it('describes an own-egg plan', () => {
    expect(describeCalculation(base)).toBe(
      'Set 1316 eggs on 2026-12-28. House on 2027-01-18, ready 2027-03-01.',
    );
  });

  it('describes a purchased-chick plan', () => {
    const text = describeCalculation({
      ...base,
      sourceMethod: 'PURCHASE_DAY_OLD_CHICKS',
      eggsRequired: null,
    });
    expect(text).toContain('Buy 1053 day-old chicks for 2027-01-18');
  });

  it('labels every status', () => {
    expect(Object.keys(PLAN_STATUS_LABELS).length).toBe(5);
  });
});
