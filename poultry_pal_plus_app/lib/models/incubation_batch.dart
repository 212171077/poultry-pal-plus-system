enum BatchStatus { planned, incubating, transferred, completed, cancelled }

BatchStatus batchStatusFromJson(String value) => switch (value) {
      'PLANNED' => BatchStatus.planned,
      'INCUBATING' => BatchStatus.incubating,
      'TRANSFERRED' => BatchStatus.transferred,
      'COMPLETED' => BatchStatus.completed,
      _ => BatchStatus.cancelled,
    };

enum CycleStatus { reserved, inHatcher, completed, cancelled }

CycleStatus cycleStatusFromJson(String value) => switch (value) {
      'RESERVED' => CycleStatus.reserved,
      'IN_HATCHER' => CycleStatus.inHatcher,
      'COMPLETED' => CycleStatus.completed,
      _ => CycleStatus.cancelled,
    };

class HatcherCycle {
  final String id;
  final String incubationBatchId;
  final String hatcherId;
  final String reference;
  final int quantity;
  final DateTime plannedTransferDate;
  final DateTime? actualTransferDate;
  final DateTime expectedHatchDate;
  final CycleStatus status;
  final int version;

  const HatcherCycle({
    required this.id,
    required this.incubationBatchId,
    required this.hatcherId,
    required this.reference,
    required this.quantity,
    required this.plannedTransferDate,
    required this.actualTransferDate,
    required this.expectedHatchDate,
    required this.status,
    required this.version,
  });

  factory HatcherCycle.fromJson(Map<String, dynamic> json) => HatcherCycle(
        id: json['id'] as String,
        incubationBatchId: json['incubationBatchId'] as String,
        hatcherId: json['hatcherId'] as String,
        reference: json['reference'] as String,
        quantity: (json['quantity'] as num).toInt(),
        plannedTransferDate: DateTime.parse(json['plannedTransferDate'] as String),
        actualTransferDate: json['actualTransferDate'] == null
            ? null
            : DateTime.parse(json['actualTransferDate'] as String),
        expectedHatchDate: DateTime.parse(json['expectedHatchDate'] as String),
        status: cycleStatusFromJson(json['status'] as String),
        version: (json['version'] as num).toInt(),
      );
}

class IncubationBatch {
  final String id;
  final String reference;
  final String equipmentId;
  final int eggsSet;
  final int eggsReserved;
  final int eggsUnassigned;
  final DateTime plannedStartDate;
  final DateTime plannedTransferDate;
  final DateTime plannedHatchDate;
  final DateTime? actualStartDate;
  final BatchStatus status;
  final String? eggSource;
  final String? notes;
  final List<HatcherCycle> hatcherCycles;
  final int version;

  const IncubationBatch({
    required this.id,
    required this.reference,
    required this.equipmentId,
    required this.eggsSet,
    required this.eggsReserved,
    required this.eggsUnassigned,
    required this.plannedStartDate,
    required this.plannedTransferDate,
    required this.plannedHatchDate,
    required this.actualStartDate,
    required this.status,
    required this.eggSource,
    required this.notes,
    required this.hatcherCycles,
    required this.version,
  });

  factory IncubationBatch.fromJson(Map<String, dynamic> json) => IncubationBatch(
        id: json['id'] as String,
        reference: json['reference'] as String,
        equipmentId: json['equipmentId'] as String,
        eggsSet: (json['eggsSet'] as num).toInt(),
        eggsReserved: (json['eggsReserved'] as num).toInt(),
        eggsUnassigned: (json['eggsUnassigned'] as num).toInt(),
        plannedStartDate: DateTime.parse(json['plannedStartDate'] as String),
        plannedTransferDate: DateTime.parse(json['plannedTransferDate'] as String),
        plannedHatchDate: DateTime.parse(json['plannedHatchDate'] as String),
        actualStartDate: json['actualStartDate'] == null
            ? null
            : DateTime.parse(json['actualStartDate'] as String),
        status: batchStatusFromJson(json['status'] as String),
        eggSource: json['eggSource'] as String?,
        notes: json['notes'] as String?,
        hatcherCycles: ((json['hatcherCycles'] as List<dynamic>?) ?? [])
            .map((e) => HatcherCycle.fromJson(e as Map<String, dynamic>))
            .toList(),
        version: (json['version'] as num).toInt(),
      );
}
