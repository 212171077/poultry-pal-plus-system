class Expense {
  final String id;
  final String expenseDate;
  final String expenseType;
  final double amount;
  final String additionalInfo;
  final String recordedBy;
  final String createdDate;

  Expense({
    required this.id,
    required this.expenseDate,
    required this.expenseType,
    required this.amount,
    required this.additionalInfo,
    required this.recordedBy,
    required this.createdDate,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      expenseDate: json['expenseDate'],
      expenseType: json['expenseType'],
      amount: json['amount'],
      additionalInfo: json['additionalInfo'] ?? '',
      recordedBy: json['recordedBy'],
      createdDate: json['createdDate'],
    );
  }
}
