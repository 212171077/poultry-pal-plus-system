class HatchResult {
  final String id;
  final String hatcherCycleId;
  final String incubationBatchId;
  final String batchReference;
  final String cycleReference;
  final int eggsTransferred;
  final int hatchedChicks;
  final int unhatchedEggs;
  final int weakChicks;
  final DateTime resultDate;

  /// Percentage, or null when no eggs were transferred.
  final double? hatchRate;
  final int version;

  const HatchResult({
    required this.id,
    required this.hatcherCycleId,
    required this.incubationBatchId,
    required this.batchReference,
    required this.cycleReference,
    required this.eggsTransferred,
    required this.hatchedChicks,
    required this.unhatchedEggs,
    required this.weakChicks,
    required this.resultDate,
    required this.hatchRate,
    required this.version,
  });

  factory HatchResult.fromJson(Map<String, dynamic> json) => HatchResult(
        id: json['id'] as String,
        hatcherCycleId: json['hatcherCycleId'] as String,
        incubationBatchId: json['incubationBatchId'] as String,
        batchReference: json['batchReference'] as String? ?? '',
        cycleReference: json['cycleReference'] as String? ?? '',
        eggsTransferred: (json['eggsTransferred'] as num).toInt(),
        hatchedChicks: (json['hatchedChicks'] as num).toInt(),
        unhatchedEggs: (json['unhatchedEggs'] as num).toInt(),
        weakChicks: (json['weakChicks'] as num?)?.toInt() ?? 0,
        resultDate: DateTime.parse(json['resultDate'] as String),
        hatchRate: (json['hatchRate'] as num?)?.toDouble(),
        version: (json['version'] as num?)?.toInt() ?? 0,
      );
}

class HatchingSummary {
  final int results;
  final int eggsTransferred;
  final int hatchedChicks;
  final int unhatchedEggs;
  final int weakChicks;
  final double? hatchRate;
  final double? weakRate;

  const HatchingSummary({
    required this.results,
    required this.eggsTransferred,
    required this.hatchedChicks,
    required this.unhatchedEggs,
    required this.weakChicks,
    required this.hatchRate,
    required this.weakRate,
  });

  factory HatchingSummary.fromJson(Map<String, dynamic> json) =>
      HatchingSummary(
        results: (json['results'] as num).toInt(),
        eggsTransferred: (json['eggsTransferred'] as num).toInt(),
        hatchedChicks: (json['hatchedChicks'] as num).toInt(),
        unhatchedEggs: (json['unhatchedEggs'] as num?)?.toInt() ?? 0,
        weakChicks: (json['weakChicks'] as num?)?.toInt() ?? 0,
        hatchRate: (json['hatchRate'] as num?)?.toDouble(),
        weakRate: (json['weakRate'] as num?)?.toDouble(),
      );
}

class HatchingTrendPoint {
  final String period;
  final int eggsTransferred;
  final int hatchedChicks;
  final double? hatchRate;

  const HatchingTrendPoint({
    required this.period,
    required this.eggsTransferred,
    required this.hatchedChicks,
    required this.hatchRate,
  });

  factory HatchingTrendPoint.fromJson(Map<String, dynamic> json) =>
      HatchingTrendPoint(
        period: json['period'] as String,
        eggsTransferred: (json['eggsTransferred'] as num).toInt(),
        hatchedChicks: (json['hatchedChicks'] as num).toInt(),
        hatchRate: (json['hatchRate'] as num?)?.toDouble(),
      );
}

class HatchingReport {
  final HatchingSummary summary;
  final List<HatchingTrendPoint> trend;
  final List<HatchResult> rows;
  final int totalElements;

  const HatchingReport({
    required this.summary,
    required this.trend,
    required this.rows,
    required this.totalElements,
  });

  factory HatchingReport.fromJson(Map<String, dynamic> json) => HatchingReport(
        summary:
            HatchingSummary.fromJson(json['summary'] as Map<String, dynamic>),
        trend: ((json['trend'] as List?) ?? const [])
            .map((e) => HatchingTrendPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        rows: (json['rows'] as List)
            .map((e) => HatchResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalElements: (json['totalElements'] as num).toInt(),
      );
}
