import '../core/utils/geo_utils.dart';

enum IncidentStatus {
  logged,
  pendingAcceptance,
  dispatched,
  enRoute,
  arrived,
  completed,
  cancelled;

  static IncidentStatus fromString(String value) => switch (value) {
    'logged'              => logged,
    'pending_acceptance'  => pendingAcceptance,
    'dispatched'          => dispatched,
    'en_route'            => enRoute,
    'arrived'             => arrived,
    'completed'           => completed,
    'cancelled'           => cancelled,
    _                     => logged,
  };

  String get dbValue => switch (this) {
    pendingAcceptance => 'pending_acceptance',
    enRoute           => 'en_route',
    _                 => name,
  };

  String get label => switch (this) {
    logged            => 'Logged',
    pendingAcceptance => 'Pending',
    dispatched        => 'Dispatched',
    enRoute           => 'En Route',
    arrived           => 'Arrived',
    completed         => 'Completed',
    cancelled         => 'Cancelled',
  };

  bool get isActive => this == logged ||
      this == pendingAcceptance ||
      this == dispatched ||
      this == enRoute ||
      this == arrived;
}

enum IncidentPriority {
  critical, high, medium, low;

  static IncidentPriority fromString(String value) => switch (value) {
    'critical' => critical,
    'high'     => high,
    'low'      => low,
    _          => medium,
  };

  String get dbValue => name;

  String get label => switch (this) {
    critical => 'Critical',
    high     => 'High',
    medium   => 'Medium',
    low      => 'Low',
  };
}

class Incident {
  final String id;
  final String reporterName;
  final String reporterPhone;
  final double? latitude;
  final double? longitude;
  final String locationDescription;
  final String natureOfEmergency;
  final String patientConditionNotes;
  final IncidentStatus status;
  final IncidentPriority priority;
  final String? createdBy;
  final String? assignedAmbulanceId;
  final String? assignedHospitalId;
  final DateTime createdAt;
  final DateTime? dispatchedAt;
  final DateTime? arrivedAt;
  final DateTime? completedAt;
  final String? photoUrl;

  const Incident({
    required this.id,
    required this.reporterName,
    required this.reporterPhone,
    this.latitude,
    this.longitude,
    required this.locationDescription,
    required this.natureOfEmergency,
    required this.patientConditionNotes,
    required this.status,
    required this.priority,
    this.createdBy,
    this.assignedAmbulanceId,
    this.assignedHospitalId,
    required this.createdAt,
    this.dispatchedAt,
    this.arrivedAt,
    this.completedAt,
    this.photoUrl,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as String,
      reporterName: json['reporter_name'] as String? ?? '',
      reporterPhone: json['reporter_phone'] as String? ?? '',
      latitude: geoLat(json['incident_location']),
      longitude: geoLng(json['incident_location']),
      locationDescription: json['location_description'] as String? ?? '',
      natureOfEmergency: json['nature_of_emergency'] as String? ?? '',
      patientConditionNotes: json['patient_condition_notes'] as String? ?? '',
      status: IncidentStatus.fromString(json['status'] as String? ?? 'logged'),
      priority: IncidentPriority.fromString(json['priority'] as String? ?? 'medium'),
      createdBy: json['created_by'] as String?,
      assignedAmbulanceId: json['assigned_ambulance_id'] as String?,
      assignedHospitalId: json['assigned_hospital_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      dispatchedAt: json['dispatched_at'] != null
          ? DateTime.parse(json['dispatched_at'] as String)
          : null,
      arrivedAt: json['arrived_at'] != null
          ? DateTime.parse(json['arrived_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      photoUrl: json['photo_url'] as String?,
    );
  }
}
