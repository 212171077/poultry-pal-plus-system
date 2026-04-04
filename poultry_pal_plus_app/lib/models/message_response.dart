class MessageResponse {
  final bool success;
  final String message;

  MessageResponse({
    required this.success,
    required this.message,
  });

  // Factory method to create a MessageResponse from JSON
  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    return MessageResponse(
      success: json['success'],
      message: json['message'] ?? 'Unknown error',
    );
  }
}
