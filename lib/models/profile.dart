enum UserRole {
  dispatcher,
  driver,
  hospital,
  admin,
  patient;

  static UserRole fromString(String value) => switch (value) {
    'dispatcher' => dispatcher,
    'driver' => driver,
    'hospital' => hospital,
    'admin' => admin,
    'patient' => patient,
    _ => driver,
  };

  String get label => switch (this) {
    dispatcher => 'Dispatcher',
    driver => 'Ambulance Driver',
    hospital => 'Hospital Staff',
    admin => 'Administrator',
    patient => 'Patient',
  };

  String get routePath => switch (this) {
    dispatcher => '/dispatcher',
    driver => '/driver',
    hospital => '/hospital',
    admin => '/admin',
    patient => '/patient',
  };
}

class Profile {
  final String id;
  final String fullName;
  final UserRole role;
  final String? hospitalId;
  final String phone;
  final String email;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    this.hospitalId,
    required this.phone,
    required this.email,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    fullName: json['full_name'] as String? ?? '',
    role: UserRole.fromString(json['role'] as String? ?? 'driver'),
    hospitalId: json['hospital_id'] as String?,
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'role': role.name,
    'hospital_id': hospitalId,
    'phone': phone,
    'email': email,
    'created_at': createdAt.toIso8601String(),
  };
}
