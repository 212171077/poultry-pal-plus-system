class SettingsData {
  double? pricePerChicken;
  double? stockPrice;
  double? pricePerBatch5;
  int? eggsPerChicken;
  double? pricePerDozen;
  int? eggsPerDozen;
  double? pricePerBatchDozen;

  SettingsData({
    this.pricePerChicken,
    this.stockPrice,
    this.pricePerBatch5,
    this.eggsPerChicken,
    this.pricePerDozen,
    this.eggsPerDozen,
    this.pricePerBatchDozen,
  });

  // Factory constructor to create a SettingsData object from a JSON map
  factory SettingsData.fromJson(Map<String, dynamic> json) {
    return SettingsData(
      pricePerChicken: json['pricePerChicken'] as double?,
      stockPrice: json['stockPrice'] as double?,
      pricePerBatch5: json['pricePerBatch5'] as double?,
      eggsPerChicken: json['eggsPerChicken'] as int?,
      pricePerDozen: json['pricePerDozen'] as double?,
      eggsPerDozen: json['eggsPerDozen'] as int?,
      pricePerBatchDozen: json['pricePerBatchDozen'] as double?,

    );
  }

  // Method to convert the SettingsData object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'pricePerChicken': pricePerChicken,
      'stockPrice': stockPrice,
      'pricePerBatch5': pricePerBatch5,
      'eggsPerChicken': eggsPerChicken,
      'pricePerDozen': pricePerDozen,
      'eggsPerDozen': eggsPerDozen,
      'pricePerBatchDozen': pricePerBatchDozen,
    };
  }
}