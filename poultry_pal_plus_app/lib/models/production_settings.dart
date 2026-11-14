class ProductionSettings {
  final String id;
  final String timeZone;
  final int incubationDays;
  final int transferDay;
  final int broodingDays;
  final double expectedHatchRate;
  final double expectedMortalityRate;
  final int defaultGrowOutDays;
  final int? supplierLeadTimeDays;
  final bool estimatesOnly;
  final int version;

  const ProductionSettings({
    required this.id,
    required this.timeZone,
    required this.incubationDays,
    required this.transferDay,
    required this.broodingDays,
    required this.expectedHatchRate,
    required this.expectedMortalityRate,
    required this.defaultGrowOutDays,
    required this.supplierLeadTimeDays,
    required this.estimatesOnly,
    required this.version,
  });

  factory ProductionSettings.fromJson(Map<String, dynamic> json) =>
      ProductionSettings(
        id: json['id'] as String,
        timeZone: json['timeZone'] as String,
        incubationDays: (json['incubationDays'] as num).toInt(),
        transferDay: (json['transferDay'] as num).toInt(),
        broodingDays: (json['broodingDays'] as num).toInt(),
        expectedHatchRate: (json['expectedHatchRate'] as num).toDouble(),
        expectedMortalityRate: (json['expectedMortalityRate'] as num).toDouble(),
        defaultGrowOutDays: (json['defaultGrowOutDays'] as num).toInt(),
        supplierLeadTimeDays: (json['supplierLeadTimeDays'] as num?)?.toInt(),
        estimatesOnly: json['estimatesOnly'] as bool? ?? false,
        version: (json['version'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'timeZone': timeZone,
        'incubationDays': incubationDays,
        'transferDay': transferDay,
        'broodingDays': broodingDays,
        'expectedHatchRate': expectedHatchRate,
        'expectedMortalityRate': expectedMortalityRate,
        'defaultGrowOutDays': defaultGrowOutDays,
        'supplierLeadTimeDays': supplierLeadTimeDays,
        'version': version,
      };
}

enum EquipmentType { incubator, hatcher, chickenHouse }

EquipmentType equipmentTypeFromJson(String value) => switch (value) {
      'INCUBATOR' => EquipmentType.incubator,
      'HATCHER' => EquipmentType.hatcher,
      _ => EquipmentType.chickenHouse,
    };

String equipmentTypeToJson(EquipmentType type) => switch (type) {
      EquipmentType.incubator => 'INCUBATOR',
      EquipmentType.hatcher => 'HATCHER',
      EquipmentType.chickenHouse => 'CHICKEN_HOUSE',
    };

class ProductionEquipment {
  final String id;
  final EquipmentType type;
  final String name;
  final int capacity;
  final bool enabled;
  final int? hatcherOccupancyDays;
  final String? notes;
  final int version;

  const ProductionEquipment({
    required this.id,
    required this.type,
    required this.name,
    required this.capacity,
    required this.enabled,
    required this.hatcherOccupancyDays,
    required this.notes,
    required this.version,
  });

  factory ProductionEquipment.fromJson(Map<String, dynamic> json) =>
      ProductionEquipment(
        id: json['id'] as String,
        type: equipmentTypeFromJson(json['type'] as String),
        name: json['name'] as String,
        capacity: (json['capacity'] as num).toInt(),
        enabled: json['enabled'] as bool? ?? true,
        hatcherOccupancyDays: (json['hatcherOccupancyDays'] as num?)?.toInt(),
        notes: json['notes'] as String?,
        version: (json['version'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'capacity': capacity,
        'enabled': enabled,
        'hatcherOccupancyDays': hatcherOccupancyDays,
        'notes': notes,
        'version': version,
      };
}
