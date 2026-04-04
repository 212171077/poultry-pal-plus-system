import 'package:intl/intl.dart';
import 'package:poultry_pal_plus_app/models/phase_transition.dart';
import 'package:poultry_pal_plus_app/models/reminder.dart';
import 'package:poultry_pal_plus_app/models/sale.dart';

import 'egg_packaging_record.dart';
import 'growing_phase.dart';
import 'expense.dart';
import 'mortality.dart';

class Coop {
  final String id;
  final String coopName;
  final String coopType;
  final String imageUrl;
  final int numberOfChickens;
  final DateTime createdDate;
  final String chickenArrivalDate;
  final String chickenAge;
  final GrowingPhase growthPhase;
  final List<Expense> expenses;
  final List<Mortality> mortalities;
  final List<Sale> sales;
  final List<EggPackagingRecord> eggPackagingRecords;
  final Reminder reminder;
  final PhaseTransition phaseTransition;
  final bool active;

  Coop({
    required this.id,
    required this.coopName,
    required this.coopType,
    required this.imageUrl,
    required this.numberOfChickens,
    required this.createdDate,
    required this.chickenArrivalDate,
    required this.chickenAge,
    required this.growthPhase,
    required this.expenses,
    required this.mortalities,
    required this.sales,
    required this.eggPackagingRecords,
    required this.reminder,
    required this.phaseTransition,
    required this.active,
  });

  factory Coop.fromJson(Map<String, dynamic> json) {
    List<Expense> expenses = [];
    List<Mortality> mortalities = [];
    List<Sale> sales = [];
    List<EggPackagingRecord> eggPackagingRecords = [];
    if (json['expenses'] != null) {
      expenses = (json['expenses'] as List?)
              ?.map((expJson) => Expense.fromJson(expJson))
              .toList() ??
          [];
    }

    if (json['mortalities'] != null) {
      mortalities = (json['mortalities'] as List?)
              ?.map((motJson) => Mortality.fromJson(motJson))
              .toList() ??
          [];
    }

    if (json['sales'] != null) {
      sales = (json['sales'] as List?)
              ?.map((saleJson) => Sale.fromJson(saleJson))
              .toList() ??
          [];
    }

    if (json['eggPackagingRecords'] != null) {
      eggPackagingRecords = (json['eggPackagingRecords'] as List?)
          ?.map((eggJson) => EggPackagingRecord.fromJson(eggJson))
          .toList() ??
          [];
    }

    String arrivalDate = 'Unknown';
    if (json['chickenArrivalDate'] != null) {
      arrivalDate = DateFormat('yyyy-MM-dd')
          .format(DateTime.parse(json['chickenArrivalDate']));
    }
    return Coop(
      id: json['id'],
      coopName: json['coopName'],
      coopType: json['coopType'],
      imageUrl: json['coopType'] == "BROILER"
          ? 'assets/broiler.jpg'
          : 'assets/layer.jpg',
      numberOfChickens: json['numberOfChickens'],
      createdDate: DateTime.parse(json['createdDate']),
      chickenArrivalDate: arrivalDate,
      chickenAge: json['chickenAge'],
      growthPhase: GrowingPhase.fromValue(json['growthPhase'] ?? 'NONE'),
      expenses: expenses,
      mortalities: mortalities,
      sales: sales,
      eggPackagingRecords: eggPackagingRecords,
      reminder: Reminder.fromJson(json['reminder']),
      phaseTransition: PhaseTransition.fromJson(json['phaseTransition']),
      active: json['active'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coopName': coopName,
      'coopType': coopType,
      'numberOfChickens': numberOfChickens,
      'createdDate': createdDate,
      'chickenArrivalDate': chickenArrivalDate,
      'chickenAge': chickenAge,
      'growthPhase': growthPhase,
      'reminder': reminder,
      'phaseTransition': phaseTransition,
      'active': active,
    };
  }
}
