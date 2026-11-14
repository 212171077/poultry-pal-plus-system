import 'package:dio/dio.dart';

import '../models/bird_placement.dart';
import '../models/hatch_result.dart';
import '../models/incubation_batch.dart';
import '../models/production_plan.dart';
import '../models/production_reminder.dart';
import '../models/production_settings.dart';
import '../models/production_snapshot.dart';
import '../models/schedule_options.dart';
import 'poultry_pal_service.dart';

/// Thrown when the API rejects a production call; [capacityConflict] is true for 409 CAPACITY_CONFLICT.
class ProductionApiException implements Exception {
  final int? status;
  final String message;
  final bool capacityConflict;

  const ProductionApiException(this.message,
      {this.status, this.capacityConflict = false});

  bool get forbidden => status == 403;

  @override
  String toString() => message;
}

class ProductionService {
  final Dio _dio = PoultryPalService().dio;
  final String _baseUrl =
      '${PoultryPalService().farmBaseUrl.replaceFirst(RegExp(r'/api/farm$'), '')}/api/v1/production';

  Future<ProductionSettings> getSettings() async => ProductionSettings.fromJson(
      await _data('GET', '/settings') as Map<String, dynamic>);

  Future<ProductionSettings> updateSettings(ProductionSettings settings) async =>
      ProductionSettings.fromJson(
          await _data('PUT', '/settings', body: settings.toJson())
              as Map<String, dynamic>);

  Future<List<ProductionEquipment>> getEquipment() async =>
      ((await _data('GET', '/equipment')) as List<dynamic>)
          .map((e) => ProductionEquipment.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<ProductionEquipment> updateEquipment(ProductionEquipment item) async =>
      ProductionEquipment.fromJson(
          await _data('PUT', '/equipment/${Uri.encodeComponent(item.id)}',
              body: item.toJson()) as Map<String, dynamic>);

  Future<List<IncubationBatch>> getBatches({BatchStatus? status}) async =>
      ((await _data('GET', '/batches', query: {
        if (status != null) 'status': status.name.toUpperCase(),
      })) as List<dynamic>)
          .map((e) => IncubationBatch.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<IncubationBatch> createBatch({
    required String equipmentId,
    required int eggsSet,
    required DateTime plannedStartDate,
    String? reference,
    String? eggSource,
  }) async =>
      _batch(await _data('POST', '/batches', body: {
        'equipmentId': equipmentId,
        'eggsSet': eggsSet,
        'plannedStartDate': _date(plannedStartDate),
        if (reference != null && reference.isNotEmpty) 'reference': reference,
        if (eggSource != null && eggSource.isNotEmpty) 'eggSource': eggSource,
      }));

  Future<IncubationBatch> startBatch(String id, {DateTime? actualDate}) async =>
      _batch(await _data('POST', '/batches/${Uri.encodeComponent(id)}/start',
          body: {if (actualDate != null) 'actualDate': _date(actualDate)}));

  Future<IncubationBatch> cancelBatch(String id) async => _batch(
      await _data('POST', '/batches/${Uri.encodeComponent(id)}/cancel', body: {}));

  Future<IncubationBatch> reserveCycle(
          String batchId, String hatcherId, int quantity) async =>
      _batch(await _data(
          'POST', '/batches/${Uri.encodeComponent(batchId)}/hatcher-cycles',
          body: {'hatcherId': hatcherId, 'quantity': quantity}));

  Future<IncubationBatch> transferCycle(String cycleId,
          {DateTime? actualDate}) async =>
      _batch(await _data(
          'POST', '/hatcher-cycles/${Uri.encodeComponent(cycleId)}/transfer',
          body: {if (actualDate != null) 'actualDate': _date(actualDate)}));

  Future<IncubationBatch> cancelCycle(String cycleId) async => _batch(await _data(
      'POST', '/hatcher-cycles/${Uri.encodeComponent(cycleId)}/cancel',
      body: {}));

  Future<List<ProductionReminder>> getReminders(
          {ReminderStatus status = ReminderStatus.open}) async =>
      ((await _data('GET', '/reminders',
              query: {'status': reminderStatusToJson(status)})) as List)
          .map((e) => ProductionReminder.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<ProductionReminder> completeReminder(String id) async =>
      ProductionReminder.fromJson(await _data(
          'POST', '/reminders/${Uri.encodeComponent(id)}/complete',
          body: {}) as Map<String, dynamic>);

  Future<HatchResult> recordHatchResult(
    String cycleId, {
    required int hatchedChicks,
    required int unhatchedEggs,
    int weakChicks = 0,
    required DateTime resultDate,
    String? notes,
  }) async =>
      HatchResult.fromJson(await _data(
          'POST', '/hatcher-cycles/${Uri.encodeComponent(cycleId)}/results',
          body: {
            'hatchedChicks': hatchedChicks,
            'unhatchedEggs': unhatchedEggs,
            'weakChicks': weakChicks,
            'resultDate': _date(resultDate),
            if (notes != null && notes.isNotEmpty) 'notes': notes,
          }) as Map<String, dynamic>);

  Future<HatchingReport> getHatchingReport(
          {DateTime? from, DateTime? to}) async =>
      HatchingReport.fromJson(await _data('GET', '/reports/hatching', query: {
        if (from != null) 'from': _date(from),
        if (to != null) 'to': _date(to),
      }) as Map<String, dynamic>);

  IncubationBatch _batch(dynamic data) =>
      IncubationBatch.fromJson(data as Map<String, dynamic>);

  Future<List<BirdPlacement>> getPlacements(
          {String? houseId, bool activeOnly = false}) async =>
      ((await _data('GET', '/placements', query: {
        if (houseId != null) 'houseId': houseId,
        if (activeOnly) 'activeOnly': true,
      })) as List)
          .map((e) => BirdPlacement.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<BirdPlacement> placeChicks({
    required PlacementSource source,
    required String houseId,
    required int quantity,
    required DateTime placementDate,
    String? sourceCycleId,
    String? sourceReference,
    DateTime? arrivalDate,
    int? ageDaysAtArrival,
    String? notes,
  }) async =>
      BirdPlacement.fromJson(await _data('POST', '/placements', body: {
        'source': placementSourceWire(source),
        'houseId': houseId,
        'quantity': quantity,
        'placementDate': _date(placementDate),
        if (sourceCycleId != null) 'sourceCycleId': sourceCycleId,
        if (sourceReference != null) 'sourceReference': sourceReference,
        if (arrivalDate != null) 'arrivalDate': _date(arrivalDate),
        if (ageDaysAtArrival != null) 'ageDaysAtArrival': ageDaysAtArrival,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }) as Map<String, dynamic>);

  /// Reuse the same [idempotencyKey] when retrying so the movement is not
  /// recorded twice.
  Future<BirdMovement> addMovement(
    String placementId, {
    required MovementType type,
    required int count,
    required DateTime date,
    required String idempotencyKey,
    bool increase = false,
    String? reason,
  }) async =>
      BirdMovement.fromJson(await _data(
          'POST', '/placements/${Uri.encodeComponent(placementId)}/movements',
          headers: {'Idempotency-Key': idempotencyKey},
          body: {
            'type': movementTypeWire(type),
            'count': count,
            'date': _date(date),
            if (type == MovementType.correction) 'increase': increase,
            if (reason != null && reason.isNotEmpty) 'reason': reason,
          }) as Map<String, dynamic>);

  Map<String, dynamic> _planBody(bool ownEggs, DateTime ready, int quantity,
          int? ageDays, String? name) =>
      {
        'sourceMethod': ownEggs ? 'INCUBATE_EGGS' : 'PURCHASE_DAY_OLD_CHICKS',
        'targetReadyDate': _date(ready),
        'targetQuantity': quantity,
        if (ageDays != null) 'targetAgeDays': ageDays,
        if (name != null && name.isNotEmpty) 'name': name,
      };

  /// Nothing is saved or reserved.
  Future<PlanCalculation> calculatePlan(
          {required bool ownEggs,
          required DateTime ready,
          required int quantity,
          int? ageDays}) async =>
      PlanCalculation.fromJson(await _data('POST', '/plans/calculate',
          body: _planBody(ownEggs, ready, quantity, ageDays, null))
          as Map<String, dynamic>);

  Future<List<ProductionPlan>> getPlans({bool openOnly = false}) async =>
      ((await _data('GET', '/plans', query: {if (openOnly) 'openOnly': true}))
              as List)
          .map((e) => ProductionPlan.fromJson(e as Map<String, dynamic>))
          .toList();

  Future<ProductionPlan> savePlan(
          {required bool ownEggs,
          required DateTime ready,
          required int quantity,
          int? ageDays,
          String? name}) async =>
      ProductionPlan.fromJson(await _data('POST', '/plans',
          body: _planBody(ownEggs, ready, quantity, ageDays, name))
          as Map<String, dynamic>);

  /// [command] is commit, recalculate, accept-recalculation or cancel.
  /// Accepting needs a [reason].
  Future<ProductionPlan> planCommand(String id, String command,
          {String? reason}) async =>
      ProductionPlan.fromJson(await _data(
          'POST', '/plans/${Uri.encodeComponent(id)}/$command',
          body: {if (reason != null && reason.isNotEmpty) 'reason': reason})
          as Map<String, dynamic>);

  /// Read-only: nothing is reserved by searching.
  Future<ScheduleOptions> searchSchedule({
    required int eggs,
    required DateTime earliestStart,
    required DateTime latestStart,
    String? incubatorId,
    String? hatcherId,
    String? houseId,
  }) async =>
      ScheduleOptions.fromJson(
          await _data('POST', '/schedule/search', body: {
        'eggs': eggs,
        'earliestStart': _date(earliestStart),
        'latestStart': _date(latestStart),
        if (incubatorId != null) 'incubatorId': incubatorId,
        if (hatcherId != null) 'hatcherId': hatcherId,
        if (houseId != null) 'houseId': houseId,
      }) as Map<String, dynamic>);

  Future<List<HouseOccupancy>> getOccupancy() async =>
      ((await _data('GET', '/occupancy')) as List)
          .map((e) => HouseOccupancy.fromJson(e as Map<String, dynamic>))
          .toList();

  /// One call with all production data, for caching offline.
  Future<ProductionSnapshot> getSnapshot() async => ProductionSnapshot.fromJson(
      await _data('GET', '/snapshot') as Map<String, dynamic>);

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<dynamic> _data(String method, String path,
      {Map<String, dynamic>? body,
      Map<String, dynamic>? query,
      Map<String, dynamic>? headers}) async {
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        '$_baseUrl$path',
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: headers),
      );
      return response.data?['data'];
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Could not reach the server.';
      final code = data is Map ? data['errorCode'] : null;
      throw ProductionApiException(message,
          status: e.response?.statusCode,
          capacityConflict: code == 'CAPACITY_CONFLICT');
    }
  }
}
