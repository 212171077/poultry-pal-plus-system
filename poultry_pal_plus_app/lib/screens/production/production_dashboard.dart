import '../../models/bird_placement.dart';
import '../../models/incubation_batch.dart';
import '../../models/production_plan.dart';
import '../../models/production_reminder.dart';
import '../../models/production_snapshot.dart';

/// Mirrors the web app's production-dashboard.ts so both show the same figures.
enum TimelineKind { transfer, hatch, placement, task, saleReady }

String timelineKindLabel(TimelineKind k) => switch (k) {
        TimelineKind.transfer => 'Transfers',
        TimelineKind.hatch => 'Hatch dates',
        TimelineKind.placement => 'Placements',
        TimelineKind.task => 'Tasks',
        TimelineKind.saleReady => 'Sale-ready',
    };

class TimelineEvent {
  final DateTime date;
  final TimelineKind kind;
  final String title;
  final String detail;

  /// Planned values are forecasts; completed ones are actual.
  final bool forecast;
  final String? equipmentId;

  const TimelineEvent({
    required this.date,
    required this.kind,
    required this.title,
    required this.detail,
    required this.forecast,
    required this.equipmentId,
  });
}

class DashboardTotals {
  final int eggsIncubating;
  final int eggsInHatcher;
  final int eggsUnassigned;
  final int activeBatches;
  final int birdsInHouses;
  final int houseCapacity;
  final int mortality;
  final int sold;
  final int openTasks;
  final int overdueTasks;
  final int plansNeedingReview;

  const DashboardTotals({
    required this.eggsIncubating,
    required this.eggsInHatcher,
    required this.eggsUnassigned,
    required this.activeBatches,
    required this.birdsInHouses,
    required this.houseCapacity,
    required this.mortality,
    required this.sold,
    required this.openTasks,
    required this.overdueTasks,
    required this.plansNeedingReview,
  });

  int get usedPercent => houseCapacity > 0
      ? ((birdsInHouses / houseCapacity) * 100).round().clamp(0, 100)
      : 0;
}

int _sum(Iterable<int> values) => values.fold(0, (a, b) => a + b);

int _transferred(IncubationBatch b) => _sum(b.hatcherCycles
    .where((c) => c.status == CycleStatus.inHatcher || c.status == CycleStatus.completed)
    .map((c) => c.quantity));

/// Totals are derived only from the source records, so they reconcile with them.
DashboardTotals buildTotals(ProductionSnapshot d) {
  final live = d.batches
      .where((b) => b.status != BatchStatus.cancelled && b.status != BatchStatus.completed)
      .toList();
  final inHatcher = live
      .expand((b) => b.hatcherCycles)
      .where((c) => c.status == CycleStatus.inHatcher);
  final incubating = live.where(
      (b) => b.status == BatchStatus.incubating || b.status == BatchStatus.transferred);
  final open = d.reminders.where((r) => r.status == ReminderStatus.open).toList();
  return DashboardTotals(
    eggsIncubating: _sum(incubating.map((b) => b.eggsSet - _transferred(b))),
    eggsInHatcher: _sum(inHatcher.map((c) => c.quantity)),
    eggsUnassigned: _sum(live.map((b) => b.eggsUnassigned)),
    activeBatches: live.length,
    birdsInHouses: _sum(d.occupancy.map((h) => h.occupied)),
    houseCapacity: _sum(d.occupancy.where((h) => h.enabled).map((h) => h.capacity)),
    mortality: _sum(d.placements.map((p) => p.mortality)),
    sold: _sum(d.placements.map((p) => p.sold)),
    openTasks: open.length,
    overdueTasks: open.where((r) => r.overdue).length,
    plansNeedingReview: d.plans.where((p) => p.status == PlanStatus.needsReview).length,
  );
}

List<TimelineEvent> buildTimeline(ProductionSnapshot d) {
  final events = <TimelineEvent>[];
  for (final batch in d.batches) {
    if (batch.status == BatchStatus.cancelled) continue;
    for (final cycle in batch.hatcherCycles) {
      if (cycle.status == CycleStatus.cancelled) continue;
      final transferDone = cycle.actualTransferDate != null;
      events.add(TimelineEvent(
        date: cycle.actualTransferDate ?? cycle.plannedTransferDate,
        kind: TimelineKind.transfer,
        title: 'Transfer ${cycle.quantity} eggs · ${batch.reference}',
        detail: transferDone ? 'Done' : 'Planned',
        forecast: !transferDone,
        equipmentId: batch.equipmentId,
      ));
      events.add(TimelineEvent(
        date: cycle.expectedHatchDate,
        kind: TimelineKind.hatch,
        title: 'Expected hatch · ${cycle.reference}',
        detail: cycle.status == CycleStatus.completed ? 'Result recorded' : 'Expected',
        forecast: cycle.status != CycleStatus.completed,
        equipmentId: cycle.hatcherId,
      ));
    }
  }
  for (final BirdPlacement p in d.placements) {
    events.add(TimelineEvent(
      date: p.placementDate,
      kind: TimelineKind.placement,
      title: 'Placed ${p.quantity} chicks · ${p.reference}',
      detail: 'Done',
      forecast: false,
      equipmentId: p.houseId,
    ));
  }
  for (final r in d.reminders) {
    if (r.status != ReminderStatus.open) continue;
    events.add(TimelineEvent(
      date: r.dueDate,
      kind: TimelineKind.task,
      title: r.title,
      detail: r.overdue ? 'Overdue' : 'Due',
      forecast: true,
      equipmentId: null,
    ));
  }
  for (final plan in d.plans) {
    if (plan.status == PlanStatus.cancelled || plan.status == PlanStatus.completed) continue;
    final c = plan.calculation;
    events.add(TimelineEvent(
      date: c.targetReadyDate,
      kind: TimelineKind.saleReady,
      title: '${c.targetQuantity} birds ready · ${plan.name ?? 'Plan'}',
      detail: plan.status == PlanStatus.draft ? 'Draft plan' : 'Planned',
      forecast: true,
      equipmentId: null,
    ));
  }
  events.sort((a, b) => a.date.compareTo(b.date));
  return events;
}
