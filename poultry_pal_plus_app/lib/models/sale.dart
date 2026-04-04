class Sale {
  final String id;
  final int numberOfDozensSold;
  final double salePricePerDozen;
  final int numberOfChickensSold;
  final double salePricePerChicken;
  final String buyerName;
  final String recordedBy;
  final String paymentStatus;
  final double totalSaleAmount;
  final String saleDate;
  final String createdDate;

  Sale({
    required this.id,
    required this.numberOfDozensSold,
    required this.salePricePerDozen,
    required this.numberOfChickensSold,
    required this.salePricePerChicken,
    required this.buyerName,
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
      numberOfChickensSold: json['numberOfChickensSold'] ?? 0,
      salePricePerChicken: json['salePricePerChicken'] ?? 0,
      buyerName: json['buyerName'],
      recordedBy: json['recordedBy'],
      paymentStatus: json['paymentStatus'],
      totalSaleAmount: json['totalSaleAmount'],
      saleDate: json['saleDate'],
      createdDate: json['createdDate'],
    );
  }
}
