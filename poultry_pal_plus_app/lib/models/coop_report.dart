

class CoopReport {
  final String coopName;
  final String coopType;
  final int totalChickens;
  final String chickenAge;
  final int totalMortality;
  final int availableChickens;
  final double profit;
  final double expenses;
  final double sales;
  final String imageUrl;

  CoopReport({
    required this.coopName,
    required this.coopType,
    required this.totalChickens,
    required this.chickenAge,
    required this.totalMortality,
    required this.availableChickens,
    required this.profit,
    required this.expenses,
    required this.sales,
    required this.imageUrl,
  });

  factory CoopReport.fromJson(Map<String, dynamic> json) {
    return CoopReport(
      coopName: json['coopName'],
      coopType: json['coopType'],
      totalChickens: json['totalChickens'],
      chickenAge: json['chickenAge'],
      totalMortality: json['totalMortality'],
      availableChickens: json['availableChickens'],
      profit: json['profit'],
      expenses: json['expenses'],
      sales: json['sales'],
      imageUrl: json['coopType'].toUpperCase() == "BROILER"
          ? 'assets/broiler.jpg'
          : 'assets/layer.jpg',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coopName': coopName,
      'coopType': coopType,
      'totalChickens': totalChickens,
      'chickenAge': chickenAge,
      'totalMortality': totalMortality,
      'availableChickens': availableChickens,
      'profit': profit,
      'expenses': expenses,
      'sales': sales,
    };
  }
}
