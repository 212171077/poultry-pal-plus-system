enum PlanStatus { draft, committed, needsReview, completed, cancelled }

PlanStatus _status(String? wire) => switch (wire) {
      'COMMITTED' => PlanStatus.committed,
      'NEEDS_REVIEW' => PlanStatus.needsReview,
      'COMPLETED' => PlanStatus.completed,
      'CANCELLED' => PlanStatus.cancelled,
      _ => PlanStatus.draft,
    };

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

class PlanCalculation {
  final bool ownEggs;
  final DateTime targetReadyDate;
  final int targetQuantity;
  final int targetAgeDays;
  final DateTime housePlacementDate;
  final DateTime hatchOrArrivalDate;
  final DateTime? incubationStartDate;
  final DateTime? transferDate;
  final DateTime? latestOrderDate;
  final int? eggsRequired;
  final int chicksRequired;
  final bool feasible;
  final List<String> constraints;
  final List<String> assumptions;

  const PlanCalculation({
    required this.ownEggs,
    required this.targetReadyDate,
    required this.targetQuantity,
    required this.targetAgeDays,
    required this.housePlacementDate,
    required this.hatchOrArrivalDate,
    this.incubationStartDate,
    this.transferDate,
    this.latestOrderDate,
    this.eggsRequired,
    required this.chicksRequired,
    required this.feasible,
    required this.constraints,
    required this.assumptions,
  });

  factory PlanCalculation.fromJson(Map<String, dynamic> json) =>
      PlanCalculation(
        ownEggs: json['sourceMethod'] == 'INCUBATE_EGGS',
        targetReadyDate: DateTime.parse(json['targetReadyDate'] as String),
        targetQuantity: (json['targetQuantity'] as num).toInt(),
        targetAgeDays: (json['targetAgeDays'] as num).toInt(),
        housePlacementDate: DateTime.parse(json['housePlacementDate'] as String),
        hatchOrArrivalDate: DateTime.parse(json['hatchOrArrivalDate'] as String),
        incubationStartDate: _date(json['incubationStartDate']),
        transferDate: _date(json['transferDate']),
        latestOrderDate: _date(json['latestOrderDate']),
        eggsRequired: (json['eggsRequired'] as num?)?.toInt(),
        chicksRequired: (json['chicksRequired'] as num).toInt(),
        feasible: json['feasible'] as bool? ?? false,
        constraints: ((json['constraints'] as List?) ?? const []).cast<String>(),
        assumptions: ((json['assumptions'] as List?) ?? const []).cast<String>(),
      );
}

class ProductionPlan {
  final String id;
  final String? name;
  final PlanStatus status;
  final PlanCalculation calculation;

  /// Set while [status] is needsReview: what the plan becomes if accepted.
  final PlanCalculation? recalculation;
  final int version;

  const ProductionPlan({
    required this.id,
    this.name,
    required this.status,
    required this.calculation,
    this.recalculation,
    required this.version,
  });

  factory ProductionPlan.fromJson(Map<String, dynamic> json) => ProductionPlan(
        id: json['id'] as String,
        name: json['name'] as String?,
        status: _status(json['status'] as String?),
        calculation:
            PlanCalculation.fromJson(json['calculation'] as Map<String, dynamic>),
        recalculation: json['recalculation'] == null
            ? null
            : PlanCalculation.fromJson(
                json['recalculation'] as Map<String, dynamic>),
        version: (json['version'] as num?)?.toInt() ?? 0,
      );
}
