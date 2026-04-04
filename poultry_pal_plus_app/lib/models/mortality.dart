class Mortality {
  final String id;
  final String dateOccurred;
  final int numberOfDeaths;
  final String reason;
  final String recordedBy;
  final String createdDate;

  Mortality({
    required this.id,
    required this.dateOccurred,
    required this.numberOfDeaths,
    required this.reason,
    required this.recordedBy,
    required this.createdDate,
  });

  factory Mortality.fromJson(Map<String, dynamic> json) {
    return Mortality(
      id: json['id'],
      dateOccurred: json['dateOccurred'],
      numberOfDeaths: json['numberOfDeaths'],
      reason: json['reason'],
      recordedBy: json['recordedBy'],
      createdDate: json['createdDate'],
    );
  }
}
