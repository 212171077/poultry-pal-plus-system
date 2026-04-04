class SettingsData {
    String? id;
    String? userId;
    String? farmId;
    String? currency;
    bool? autoCreateReminders;
    bool? salesAlerts;
    bool? mortalityAlerts;
    bool? expenseAlerts;
    bool? dailyReminders;

    SettingsData({
        this.id,
        this.userId,
        this.farmId,
        this.currency,
        this.autoCreateReminders,
        this.salesAlerts,
        this.mortalityAlerts,
        this.expenseAlerts,
        this.dailyReminders,
    });

    // Factory constructor to create a SettingsData object from a JSON map
    factory SettingsData.fromJson(Map<String, dynamic> json) {
        return SettingsData(
            id: json['id'] as String?,
            userId: json['userId'] as String?,
            farmId: json['farmId'] as String?,
            currency: json['currency'] as String?,
            salesAlerts: json['salesAlerts'] as bool?,
            mortalityAlerts: json['mortalityAlerts'] as bool?,
            expenseAlerts: json['expenseAlerts'] as bool?,
            autoCreateReminders: json['autoCreateReminders'] as bool?,
            dailyReminders: json['dailyReminders'] as bool?);
    }

    // Method to convert the SettingsData object to a JSON map
    Map<String, dynamic> toJson() {
        return {
            'id': id,
            'userId': userId,
            'farmId': farmId,
            'currency': currency,
            'autoCreateReminders': autoCreateReminders,
            'salesAlerts': autoCreateReminders,
            'mortalityAlerts': autoCreateReminders,
            'expenseAlerts': expenseAlerts,
            'dailyReminders': dailyReminders,
        };
    }
}
