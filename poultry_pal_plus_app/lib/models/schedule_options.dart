class ScheduleCandidate {
  final DateTime start;
  final DateTime transferDate;
  final DateTime hatchDate;
  final DateTime houseArrivalDate;
  final bool feasible;
  final List<String> reasons;

  const ScheduleCandidate({
    required this.start,
    required this.transferDate,
    required this.hatchDate,
    required this.houseArrivalDate,
    required this.feasible,
    required this.reasons,
  });

  factory ScheduleCandidate.fromJson(Map<String, dynamic> json) =>
      ScheduleCandidate(
        start: DateTime.parse(json['start'] as String),
        transferDate: DateTime.parse(json['transferDate'] as String),
        hatchDate: DateTime.parse(json['hatchDate'] as String),
        houseArrivalDate: DateTime.parse(json['houseArrivalDate'] as String),
        feasible: json['feasible'] as bool? ?? false,
        reasons: ((json['reasons'] as List?) ?? const []).cast<String>(),
      );
}

class ScheduleWindow {
  final DateTime from;
  final DateTime to;

  const ScheduleWindow({required this.from, required this.to});

  factory ScheduleWindow.fromJson(Map<String, dynamic> json) => ScheduleWindow(
        from: DateTime.parse(json['from'] as String),
        to: DateTime.parse(json['to'] as String),
      );
}

class ScheduleOptions {
  final int eggs;
  final int expectedChicks;
  final DateTime? recommendedStart;
  final List<ScheduleWindow> windows;
  final List<ScheduleCandidate> candidates;
  final String explanation;
  final List<String> assumptions;

  const ScheduleOptions({
    required this.eggs,
    required this.expectedChicks,
    this.recommendedStart,
    required this.windows,
    required this.candidates,
    required this.explanation,
    required this.assumptions,
  });

  factory ScheduleOptions.fromJson(Map<String, dynamic> json) =>
      ScheduleOptions(
        eggs: (json['eggs'] as num).toInt(),
        expectedChicks: (json['expectedChicks'] as num).toInt(),
        recommendedStart: json['recommendedStart'] == null
            ? null
            : DateTime.parse(json['recommendedStart'] as String),
        windows: ((json['windows'] as List?) ?? const [])
            .map((e) => ScheduleWindow.fromJson(e as Map<String, dynamic>))
            .toList(),
        candidates: ((json['candidates'] as List?) ?? const [])
            .map((e) => ScheduleCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
        explanation: json['explanation'] as String? ?? '',
        assumptions: ((json['assumptions'] as List?) ?? const []).cast<String>(),
      );
}
