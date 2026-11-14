import 'bird_placement.dart';
import 'incubation_batch.dart';
import 'production_plan.dart';
import 'production_reminder.dart';
import 'production_settings.dart';

/// Everything the production screens read, in one response, so it can be cached for offline use.
class ProductionSnapshot {
  final DateTime generatedAt;
  final ProductionSettings settings;
  final List<ProductionEquipment> equipment;
  final List<IncubationBatch> batches;
  final List<ProductionReminder> reminders;
  final List<BirdPlacement> placements;
  final List<HouseOccupancy> occupancy;
  final List<ProductionPlan> plans;

  const ProductionSnapshot({
    required this.generatedAt,
    required this.settings,
    required this.equipment,
    required this.batches,
    required this.reminders,
    required this.placements,
    required this.occupancy,
    required this.plans,
  });

  static List<T> _list<T>(
          dynamic value, T Function(Map<String, dynamic>) parse) =>
      ((value as List?) ?? const [])
          .map((e) => parse(e as Map<String, dynamic>))
          .toList();

  factory ProductionSnapshot.fromJson(Map<String, dynamic> json) =>
      ProductionSnapshot(
        generatedAt: DateTime.parse(json['generatedAt'] as String),
        settings: ProductionSettings.fromJson(
            json['settings'] as Map<String, dynamic>),
        equipment: _list(json['equipment'], ProductionEquipment.fromJson),
        batches: _list(json['batches'], IncubationBatch.fromJson),
        reminders: _list(json['reminders'], ProductionReminder.fromJson),
        placements: _list(json['placements'], BirdPlacement.fromJson),
        occupancy: _list(json['occupancy'], HouseOccupancy.fromJson),
        plans: _list(json['plans'], ProductionPlan.fromJson),
      );
}
