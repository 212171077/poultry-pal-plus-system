enum ReminderStatus { open, completed, cancelled }

ReminderStatus reminderStatusFromJson(String value) => switch (value) {
      'COMPLETED' => ReminderStatus.completed,
      'CANCELLED' => ReminderStatus.cancelled,
      _ => ReminderStatus.open,
    };

String reminderStatusToJson(ReminderStatus status) => switch (status) {
      ReminderStatus.open => 'OPEN',
      ReminderStatus.completed => 'COMPLETED',
      ReminderStatus.cancelled => 'CANCELLED',
    };

class ProductionReminder {
  final String id;
  final String? sourceReference;
  final String taskType;
  final String title;
  final DateTime dueDate;
  final ReminderStatus status;
  final bool overdue;
  final String? completedBy;
  final int version;

  const ProductionReminder({
    required this.id,
    required this.sourceReference,
    required this.taskType,
    required this.title,
    required this.dueDate,
    required this.status,
    required this.overdue,
    required this.completedBy,
    required this.version,
  });

  factory ProductionReminder.fromJson(Map<String, dynamic> json) =>
      ProductionReminder(
        id: json['id'] as String,
        sourceReference: json['sourceReference'] as String?,
        taskType: json['taskType'] as String,
        title: json['title'] as String,
        dueDate: DateTime.parse(json['dueDate'] as String),
        status: reminderStatusFromJson(json['status'] as String),
        overdue: json['overdue'] as bool? ?? false,
        completedBy: json['completedBy'] as String?,
        version: (json['version'] as num?)?.toInt() ?? 0,
      );
}
