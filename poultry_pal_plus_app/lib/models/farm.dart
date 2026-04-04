import 'package:poultry_pal_plus_app/models/user.dart';

import 'address.dart';
import 'coop.dart';
import 'farm_report.dart';

class Farm {
  final String id;
  final String farmName;
  final Address address;
  final List<Coop> coops;
  final String createdDate;
  final List<User> users;
  final FarmReport farmReport;

  Farm({
    required this.id,
    required this.farmName,
    required this.address,
    required this.coops,
    required this.createdDate,
    required this.users,
    required this.farmReport,
  });

  factory Farm.fromJson(Map<String, dynamic> json) {
    return Farm(
      id: json['id'],
      farmName: json['farmName'],
      address: Address.fromJson(json['address']),
      coops: (json['coops'] as List).map((coopJson) => Coop.fromJson(coopJson)).toList(),
      createdDate: json['createdDate'],
      users: (json['users'] as List).map((userJson) => User.fromJson(userJson)).toList(),
      farmReport: FarmReport.fromJson(json['farmReport']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'farmName': farmName,
      'address': address.toJson(),
      'coops': (coops
          .toList()
        ..sort((a, b) => (b.active ? 1 : 0) - (a.active ? 1 : 0)))
          .map((coop) => coop.toJson())
          .toList(),
      'createdDate': createdDate,
      'users': users,
      'farmReport': farmReport,
    };
  }
}