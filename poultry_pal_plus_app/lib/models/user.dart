class User {
  final String id;
  final String name;
  final String surname;
  final String phoneNumber;
  final String farmId;
  final String createdDate;
  final String email;
  final List<String> roles;
  final List<String> userCoopIds;
  final List<String> roleFriendlyNames;
  final bool active;
  final bool farmOwner;
  final List<String> permissions;

  User({
    required this.id,
    required this.name,
    required this.surname,
    required this.phoneNumber,
    required this.farmId,
    required this.createdDate,
    required this.email,
    required this.roles,
    required this.roleFriendlyNames,
    required this.active,
    required this.farmOwner,
    required this.userCoopIds,
    this.permissions = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      surname: json['surname'],
      phoneNumber: json['phoneNumber'],
      farmId: json['farmId'],
      createdDate: json['createdDate'],
      email: json['email'],
      roles: List<String>.from(json['roles']),
     userCoopIds: json['userCoopIds'] != null ? List<String>.from(json['userCoopIds']) : [],
      roleFriendlyNames: List<String>.from(json['roleFriendlyNames']),
      active: json['active'],
      farmOwner: json['farmOwner'],
      permissions: json['permissions'] != null ? List<String>.from(json['permissions']) : [],
    );
  }

  /// The farm owner always manages production; others need an explicit grant.
  bool get canManageProduction => farmOwner || permissions.contains('PRODUCTION_MANAGE');

  String getFormattedRoles() {
    return roleFriendlyNames.join(' | ');
  }
}