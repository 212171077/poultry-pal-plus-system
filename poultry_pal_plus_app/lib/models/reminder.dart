class Reminder {
  final String id;
  final List<Map<String, dynamic>> upcomingReminders;
  final List<Map<String, dynamic>> overdueTasks;

  Reminder({
    required this.id,
    required this.upcomingReminders,
    required this.overdueTasks,
  });

  factory Reminder.fromJson(Map<String, dynamic>? json) {

    if (json == null || json['id'] == null || json['upcomingReminders'] == null || json['overdueTasks'] == null) {
      return Reminder(
        id: 'null_id',
        upcomingReminders: [],
        overdueTasks: [],
      );
    }

    return Reminder(
      id: json['id'] as String,
      upcomingReminders: (json['upcomingReminders'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [],  // Handle null lists by defaulting to empty
      overdueTasks: (json['overdueTasks'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [],  // Handle null lists by defaulting to empty
    );
  }

}
