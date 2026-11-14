enum PlacementSource { ownHatch, purchasedDayOld }

enum MovementType { mortality, sale, transfer, otherRemoval, correction }

String _wire(Enum value) {
  final name = value.name;
  return name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}').toUpperCase();
}

T _parse<T extends Enum>(List<T> values, String? wire, T fallback) {
  for (final v in values) {
    if (_wire(v) == wire) return v;
  }
  return fallback;
}

String placementSourceWire(PlacementSource s) => _wire(s);
String movementTypeWire(MovementType t) => _wire(t);

class BirdMovement {
  final String id;
  final String placementId;
  final MovementType type;
  final int count;
  final bool increase;
  final DateTime date;
  final String? reason;

  const BirdMovement({
    required this.id,
    required this.placementId,
    required this.type,
    required this.count,
    required this.increase,
    required this.date,
    this.reason,
  });

  factory BirdMovement.fromJson(Map<String, dynamic> json) => BirdMovement(
        id: json['id'] as String,
        placementId: json['placementId'] as String,
        type: _parse(MovementType.values, json['type'] as String?,
            MovementType.otherRemoval),
        count: (json['count'] as num).toInt(),
        increase: json['increase'] as bool? ?? false,
        date: DateTime.parse(json['date'] as String),
        reason: json['reason'] as String?,
      );
}

class BirdPlacement {
  final String id;
  final String reference;
  final PlacementSource source;
  final String? sourceCycleId;
  final String? sourceReference;
  final String houseId;
  final int quantity;
  final DateTime placementDate;
  final int remaining;
  final int mortality;
  final int sold;
  final int otherRemovals;
  final bool active;
  final List<BirdMovement> movements;
  final int version;

  const BirdPlacement({
    required this.id,
    required this.reference,
    required this.source,
    this.sourceCycleId,
    this.sourceReference,
    required this.houseId,
    required this.quantity,
    required this.placementDate,
    required this.remaining,
    required this.mortality,
    required this.sold,
    required this.otherRemovals,
    required this.active,
    this.movements = const [],
    required this.version,
  });

  factory BirdPlacement.fromJson(Map<String, dynamic> json) => BirdPlacement(
        id: json['id'] as String,
        reference: json['reference'] as String? ?? '',
        source: _parse(PlacementSource.values, json['source'] as String?,
            PlacementSource.purchasedDayOld),
        sourceCycleId: json['sourceCycleId'] as String?,
        sourceReference: json['sourceReference'] as String?,
        houseId: json['houseId'] as String,
        quantity: (json['quantity'] as num).toInt(),
        placementDate: DateTime.parse(json['placementDate'] as String),
        remaining: (json['remaining'] as num).toInt(),
        mortality: (json['mortality'] as num?)?.toInt() ?? 0,
        sold: (json['sold'] as num?)?.toInt() ?? 0,
        otherRemovals: (json['otherRemovals'] as num?)?.toInt() ?? 0,
        active: json['status'] == 'ACTIVE',
        movements: ((json['movements'] as List?) ?? const [])
            .map((e) => BirdMovement.fromJson(e as Map<String, dynamic>))
            .toList(),
        version: (json['version'] as num?)?.toInt() ?? 0,
      );
}

class HouseOccupancy {
  final String houseId;
  final String name;
  final bool enabled;
  final int capacity;
  final int occupied;
  final int available;

  const HouseOccupancy({
    required this.houseId,
    required this.name,
    required this.enabled,
    required this.capacity,
    required this.occupied,
    required this.available,
  });

  factory HouseOccupancy.fromJson(Map<String, dynamic> json) => HouseOccupancy(
        houseId: json['houseId'] as String,
        name: json['name'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        capacity: (json['capacity'] as num).toInt(),
        occupied: (json['occupied'] as num).toInt(),
        available: (json['available'] as num).toInt(),
      );
}
