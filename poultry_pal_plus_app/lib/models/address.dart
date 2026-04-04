class Address {
  final String? addressLine1;
  final String? addressLine2;
  final String? state;
  final String? city;
  final String? postalCode;
  final String? country;

  Address({
    this.addressLine1,
    this.addressLine2,
    this.state,
    this.city,
    this.postalCode,
    this.country,
  });

  factory Address.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return Address(); // Return an empty Address if json is null
    }
    return Address(
      addressLine1: json['addressLine1'],addressLine2: json['addressLine2'],
      state: json['state'],
      city: json['city'],
      postalCode: json['postalCode'],
      country: json['country'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'state': state,
      'city': city,
      'postalCode': postalCode,
      'country': country,
    };
  }
}