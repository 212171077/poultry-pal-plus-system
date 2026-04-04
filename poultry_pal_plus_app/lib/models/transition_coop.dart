class TransitionCoop {
  final String id;
  final String displayName;

  TransitionCoop({
    required this.id,
    required this.displayName,
  });

  factory TransitionCoop.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return TransitionCoop(id: "null",displayName: "null");
    }

    return TransitionCoop(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
    };
  }
}
