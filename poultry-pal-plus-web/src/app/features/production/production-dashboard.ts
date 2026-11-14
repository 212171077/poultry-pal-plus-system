import {
  BirdPlacement,
  HouseOccupancy,
  IncubationBatch,
  ProductionPlan,
  ProductionReminder,
} from './production-api';

export type TimelineKind = 'TRANSFER' | 'HATCH' | 'PLACEMENT' | 'TASK' | 'SALE_READY';

export interface TimelineEvent {
  readonly date: string;
  readonly kind: TimelineKind;
  readonly title: string;
  readonly detail: string;
  /** Planned values are forecasts; completed ones are actual. */
  readonly forecast: boolean;
  readonly equipmentId: string | null;
}

export interface DashboardTotals {
  readonly eggsIncubating: number;
  readonly eggsInHatcher: number;
  readonly eggsUnassigned: number;
  readonly activeBatches: number;
  readonly birdsInHouses: number;
  readonly houseCapacity: number;
  readonly mortality: number;
  readonly sold: number;
  readonly openTasks: number;
  readonly overdueTasks: number;
  readonly plansNeedingReview: number;
}

export interface DashboardInput {
  readonly batches: readonly IncubationBatch[];
  readonly reminders: readonly ProductionReminder[];
  readonly placements: readonly BirdPlacement[];
  readonly occupancy: readonly HouseOccupancy[];
  readonly plans: readonly ProductionPlan[];
}

const sum = (values: readonly number[]): number => values.reduce((a, b) => a + b, 0);

/** Totals are derived only from the source records, so they always reconcile with them. */
export function buildTotals(input: DashboardInput): DashboardTotals {
  const live = input.batches.filter((b) => b.status !== 'CANCELLED' && b.status !== 'COMPLETED');
  const activeCycles = live
    .flatMap((b) => b.hatcherCycles)
    .filter((c) => c.status === 'IN_HATCHER');
  const incubating = live.filter((b) => b.status === 'INCUBATING' || b.status === 'TRANSFERRED');
  const open = input.reminders.filter((r) => r.status === 'OPEN');
  return {
    eggsIncubating: sum(incubating.map((b) => b.eggsSet - transferred(b))),
    eggsInHatcher: sum(activeCycles.map((c) => c.quantity)),
    eggsUnassigned: sum(live.map((b) => b.eggsUnassigned)),
    activeBatches: live.length,
    birdsInHouses: sum(input.occupancy.map((h) => h.occupied)),
    houseCapacity: sum(input.occupancy.filter((h) => h.enabled).map((h) => h.capacity)),
    mortality: sum(input.placements.map((p) => p.mortality)),
    sold: sum(input.placements.map((p) => p.sold)),
    openTasks: open.length,
    overdueTasks: open.filter((r) => r.overdue).length,
    plansNeedingReview: input.plans.filter((p) => p.status === 'NEEDS_REVIEW').length,
  };
}

function transferred(batch: IncubationBatch): number {
  return sum(
    batch.hatcherCycles
      .filter((c) => c.status === 'IN_HATCHER' || c.status === 'COMPLETED')
      .map((c) => c.quantity),
  );
}

export function buildTimeline(input: DashboardInput): TimelineEvent[] {
  const events: TimelineEvent[] = [];
  for (const batch of input.batches) {
    if (batch.status === 'CANCELLED') continue;
    for (const cycle of batch.hatcherCycles) {
      if (cycle.status === 'CANCELLED') continue;
      const transferDone = cycle.actualTransferDate !== null;
      events.push({
        date: cycle.actualTransferDate ?? cycle.plannedTransferDate,
        kind: 'TRANSFER',
        title: `Transfer ${cycle.quantity} eggs · ${batch.reference}`,
        detail: transferDone ? 'Done' : 'Planned',
        forecast: !transferDone,
        equipmentId: batch.equipmentId,
      });
      events.push({
        date: cycle.expectedHatchDate,
        kind: 'HATCH',
        title: `Expected hatch · ${cycle.reference}`,
        detail: cycle.status === 'COMPLETED' ? 'Result recorded' : 'Expected',
        forecast: cycle.status !== 'COMPLETED',
        equipmentId: cycle.hatcherId,
      });
    }
  }
  for (const p of input.placements) {
    events.push({
      date: p.placementDate,
      kind: 'PLACEMENT',
      title: `Placed ${p.quantity} chicks · ${p.reference}`,
      detail: 'Done',
      forecast: false,
      equipmentId: p.houseId,
    });
  }
  for (const r of input.reminders) {
    if (r.status !== 'OPEN') continue;
    events.push({
      date: r.dueDate,
      kind: 'TASK',
      title: r.title,
      detail: r.overdue ? 'Overdue' : 'Due',
      forecast: true,
      equipmentId: null,
    });
  }
  for (const plan of input.plans) {
    if (plan.status === 'CANCELLED' || plan.status === 'COMPLETED') continue;
    const c = plan.calculation;
    events.push({
      date: c.targetReadyDate,
      kind: 'SALE_READY',
      title: `${c.targetQuantity} birds ready · ${plan.name ?? 'Plan'}`,
      detail: plan.status === 'DRAFT' ? 'Draft plan' : 'Planned',
      forecast: true,
      equipmentId: null,
    });
  }
  return events.sort((a, b) => a.date.localeCompare(b.date));
}
