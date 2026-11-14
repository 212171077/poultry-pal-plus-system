import { buildTimeline, buildTotals, DashboardInput } from './production-dashboard';
import { BirdPlacement, HatcherCycle, IncubationBatch } from './production-api';

const cycle = (over: Partial<HatcherCycle>): HatcherCycle => ({
  id: 'c1',
  incubationBatchId: 'b1',
  hatcherId: 'h1',
  reference: 'C-1',
  quantity: 300,
  plannedTransferDate: '2026-03-19',
  actualTransferDate: null,
  expectedHatchDate: '2026-03-22',
  status: 'RESERVED',
  version: 1,
  ...over,
});

const batch = (over: Partial<IncubationBatch>): IncubationBatch => ({
  id: 'b1',
  reference: 'B-1',
  equipmentId: 'i1',
  eggsSet: 1000,
  eggsReserved: 300,
  eggsUnassigned: 700,
  plannedStartDate: '2026-03-01',
  plannedTransferDate: '2026-03-19',
  plannedHatchDate: '2026-03-22',
  actualStartDate: '2026-03-01',
  status: 'INCUBATING',
  eggSource: null,
  notes: null,
  hatcherCycles: [cycle({})],
  version: 1,
  ...over,
});

const placement = {
  id: 'p1',
  reference: 'P-1',
  houseId: 'ho1',
  quantity: 100,
  mortality: 4,
  sold: 10,
  remaining: 86,
  placementDate: '2026-04-01',
} as BirdPlacement;

const input = (batches: IncubationBatch[]): DashboardInput => ({
  batches,
  reminders: [],
  placements: [placement],
  occupancy: [
    { houseId: 'ho1', name: 'House', enabled: true, capacity: 500, occupied: 86, available: 414 },
  ],
  plans: [],
});

describe('production dashboard', () => {
  it('reconciles egg and bird totals with the source records', () => {
    const t = buildTotals(
      input([
        batch({
          hatcherCycles: [cycle({ status: 'IN_HATCHER', actualTransferDate: '2026-03-19' })],
          status: 'TRANSFERRED',
        }),
        batch({ id: 'b2', status: 'CANCELLED' }),
      ]),
    );
    expect(t.activeBatches).toBe(1);
    expect(t.eggsInHatcher).toBe(300);
    expect(t.eggsIncubating).toBe(700);
    expect(t.eggsUnassigned).toBe(700);
    expect(t.birdsInHouses).toBe(86);
    expect(t.mortality).toBe(4);
    expect(t.sold).toBe(10);
  });

  it('marks planned events as forecast and sorts by date', () => {
    const events = buildTimeline(input([batch({})]));
    expect(events.map((e) => e.date)).toEqual(['2026-03-19', '2026-03-22', '2026-04-01']);
    expect(events.map((e) => e.forecast)).toEqual([true, true, false]);
  });
});
