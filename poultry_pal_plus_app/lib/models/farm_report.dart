import 'coop_report.dart';

class FarmReport {
  final int totalChickens;
  final double totalSales;
  final double totalExpenses;
  final int totalMortalities;
  final List<CoopReport> coopReports;

  FarmReport({
    required this.totalChickens,
    required this.totalSales,
    required this.totalExpenses,
    required this.totalMortalities,
    required this.coopReports,
  });

  factory FarmReport.fromJson(Map<String, dynamic> json) {
    return FarmReport(
      totalChickens: json['totalChickens'],
      totalSales: json['totalSales'],
      totalExpenses: json['totalExpenses'],
      totalMortalities: json['totalMortalities'],
      coopReports: (json['coopReports'] as List).map((json) => CoopReport.fromJson(json)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalChickens': totalChickens,
      'totalSales': totalSales,
      'totalExpenses': totalExpenses,
      'totalMortalities': totalMortalities,
      'coopReports': coopReports.map((report) => report.toJson()).toList(),
    };
  }
}