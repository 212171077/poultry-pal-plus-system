class EggPackagingRecord {
  final String id;
  final String createdDate;
  final String eggSize;
  final String boxSize;
  final int numberOfBoxes;
  final int totalEggs;
  final String userId;
  final String additionalInfo;

  EggPackagingRecord({
    required this.id,
    required this.createdDate,
    required this.eggSize,
    required this.boxSize,
    required this.numberOfBoxes,
    required this.totalEggs,
    required this.userId,
    required this.additionalInfo,
  });

  factory EggPackagingRecord.fromJson(Map<String, dynamic> json) {
    return EggPackagingRecord(
      id: json['id'],
      createdDate: json['createdDate'],
      eggSize: json['eggSize'],
      boxSize: json['boxSize'],
      numberOfBoxes: json['numberOfBoxes'],
      totalEggs: json['totalEggs'],
      userId: json['userId'],
      additionalInfo: json['additionalInfo'] ?? '',
    );
  }
}
