class Trip {
  final String id;
  final String incidentId;
  final String patientId;
  final String? ambulanceId;
  final String? driverId;
  final String status;
  final double baseFare;
  final double pricePerKm;
  final double? distanceKm;
  final double? totalFare;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;

  const Trip({
    required this.id,
    required this.incidentId,
    required this.patientId,
    this.ambulanceId,
    this.driverId,
    required this.status,
    required this.baseFare,
    required this.pricePerKm,
    this.distanceKm,
    this.totalFare,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.requestedAt,
    this.acceptedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id:             json['id'] as String,
      incidentId:     json['incident_id'] as String,
      patientId:      json['patient_id'] as String,
      ambulanceId:    json['ambulance_id'] as String?,
      driverId:       json['driver_id'] as String?,
      status:         json['status'] as String? ?? 'requested',
      baseFare:       (json['base_fare'] as num?)?.toDouble() ?? 0,
      pricePerKm:     (json['price_per_km'] as num?)?.toDouble() ?? 0,
      distanceKm:     (json['distance_km'] as num?)?.toDouble(),
      totalFare:      (json['total_fare'] as num?)?.toDouble(),
      paymentMethod:  json['payment_method'] as String? ?? 'cash',
      paymentStatus:  json['payment_status'] as String? ?? 'pending',
      requestedAt:    DateTime.parse(json['requested_at'] as String),
      acceptedAt:     json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      completedAt:    json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      cancelledAt:    json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      cancelReason:   json['cancel_reason'] as String?,
    );
  }
}
