/// How eggs are sold; the codes match the backend `EggSalePackaging` enum.
class EggSalePackaging {
  final String code;
  final String label;
  final String unit;
  final int eggs;

  const EggSalePackaging(this.code, this.label, this.unit, this.eggs);

  static const List<EggSalePackaging> all = [
    EggSalePackaging('TRAY_60', 'Tray of 60 eggs', 'tray', 60),
    EggSalePackaging('TRAY_30', 'Tray of 30 eggs', 'tray', 30),
    EggSalePackaging('BOX_360', 'Box (60 eggs × 6)', 'box', 360),
    EggSalePackaging('SINGLE', 'Single eggs', 'egg', 1),
  ];

  static const List<String> eggSizes = ['Large', 'Small'];

  static EggSalePackaging? fromCode(String? code) {
    for (final p in all) {
      if (p.code == code) return p;
    }
    return null;
  }
}

class Sale {
  final String id;
  final int numberOfDozensSold;
  final double salePricePerDozen;
  final String? eggSize;
  final String? eggPackaging;
  final int quantitySold;
  final double pricePerUnit;
  final int totalEggsSold;
  final int numberOfChickensSold;
  final double salePricePerChicken;
  final String additionalInfo;
  final String recordedBy;
  final String paymentStatus;
  final double totalSaleAmount;
  final String saleDate;
  final String createdDate;

  Sale({
    required this.id,
    required this.numberOfDozensSold,
    required this.salePricePerDozen,
    this.eggSize,
    this.eggPackaging,
    this.quantitySold = 0,
    this.pricePerUnit = 0,
    this.totalEggsSold = 0,
    required this.numberOfChickensSold,
    required this.salePricePerChicken,
    required this.additionalInfo,
    required this.recordedBy,
    required this.paymentStatus,
    required this.totalSaleAmount,
    required this.saleDate,
    required this.createdDate,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'],
      numberOfDozensSold: json['numberOfDozensSold'] ?? 0,
      salePricePerDozen: json['salePricePerDozen'] ?? 0,
      eggSize: json['eggSize'],
      eggPackaging: json['eggPackaging'],
      quantitySold: json['quantitySold'] ?? 0,
      pricePerUnit: (json['pricePerUnit'] ?? 0).toDouble(),
      totalEggsSold: json['totalEggsSold'] ?? 0,
      numberOfChickensSold: json['numberOfChickensSold'] ?? 0,
      salePricePerChicken: json['salePricePerChicken'] ?? 0,
      additionalInfo: json['additionalInfo'] ?? '',
      recordedBy: json['recordedBy'],
      paymentStatus: json['paymentStatus'],
      totalSaleAmount: json['totalSaleAmount'],
      saleDate: json['saleDate'],
      createdDate: json['createdDate'],
    );
  }
}
